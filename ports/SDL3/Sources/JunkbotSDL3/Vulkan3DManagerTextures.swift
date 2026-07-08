// Texture loading for `Vulkan3DManager` - the backdrop image, level background/foreground
// decals, and Junkbot's baked chest-emblem PNG (see `tools/Junkbot3D/Sources/Junkbot3D/main.swift`'s
// `--bake-all`, which now also writes `Models3D/junkbot_decal.png`).
//
// `CoreGraphics`/`ImageIO` (Darwin's `Metal3DManager.swift` uses these to decode PNGs manually,
// working around `MTKTextureLoader` failing on indexed-color PNGs) don't exist on Android at all.
// `SDL3Image` (already a `JunkbotGame` dependency, used for every 2D sprite) is the portable
// decoder instead: `IMG_Load` -> `SDL_ConvertSurface(..., SDL_PIXELFORMAT_RGBA32)` gives a plain
// top-left-origin RGBA8 buffer, uploaded into a `VK_IMAGE_TILING_LINEAR` image directly (see
// `Vulkan3DManager.swift`'s doc comment for why linear tiling, skipping a staging-buffer + copy
// command, is an acceptable simplification here).

import CSDL3
import CSDL3Image
import CVulkan
import Foundation
import JunkbotCore

extension Vulkan3DManager {
  /// Decodes `path` and uploads it as a sampled `VkImage` + descriptor set, ready to bind at
  /// draw time. Returns `nil` (logging why) on any failure - callers already treat a missing
  /// texture as "skip drawing this quad", matching `Metal3DManager.swift`'s own failure handling.
  func loadTextureFromDisk(path: String) -> GPUTexture? {
    guard let device, let descriptorPool, let descriptorSetLayout, let sampler else { return nil }

    guard let rawSurface = IMG_Load(path) else {
      log("Vulkan3DManager: IMG_Load failed for \(path)")
      return nil
    }
    defer { SDL_DestroySurface(rawSurface) }
    guard let convertedSurface = SDL_ConvertSurface(rawSurface, SDL_PIXELFORMAT_RGBA32) else {
      log("Vulkan3DManager: SDL_ConvertSurface failed for \(path)")
      return nil
    }
    defer { SDL_DestroySurface(convertedSurface) }

    let width = UInt32(convertedSurface.pointee.w)
    let height = UInt32(convertedSurface.pointee.h)
    guard width > 0, height > 0, let pixels = convertedSurface.pointee.pixels else { return nil }
    let pitch = Int(convertedSurface.pointee.pitch)

    guard
      let (image, memory) = makeImage(
        width: width, height: height, format: VK_FORMAT_R8G8B8A8_UNORM,
        tiling: VK_IMAGE_TILING_LINEAR,
        usage: UInt32(VK_IMAGE_USAGE_SAMPLED_BIT.rawValue),
        properties: UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
          | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue))
    else { return nil }

    var layout = VkSubresourceLayout()
    var subresource = VkImageSubresource(
      aspectMask: UInt32(VK_IMAGE_ASPECT_COLOR_BIT.rawValue), mipLevel: 0, arrayLayer: 0)
    vkGetImageSubresourceLayout(device, image, &subresource, &layout)

    var mapped: UnsafeMutableRawPointer?
    vkMapMemory(device, memory, 0, VK_WHOLE_SIZE, 0, &mapped)
    if let mapped {
      let dstBase = mapped.assumingMemoryBound(to: UInt8.self)
      let srcBase = pixels.assumingMemoryBound(to: UInt8.self)
      let rowBytes = Int(width) * 4
      for row in 0..<Int(height) {
        memcpy(dstBase + Int(layout.offset) + row * Int(layout.rowPitch), srcBase + row * pitch, rowBytes)
      }
    }
    vkUnmapMemory(device, memory)

    // Linear-tiled images start `VK_IMAGE_LAYOUT_UNDEFINED` (or `PREINITIALIZED` if data was
    // written before any layout transition - `UNDEFINED` is simpler and still valid since we
    // wrote the pixel data with the memory mapped directly, not via a copy command that would
    // care about the *previous* layout's contents). Transition once, immediately, via a tiny
    // one-off command buffer.
    transitionImageLayout(
      image: image, from: VK_IMAGE_LAYOUT_UNDEFINED, to: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

    guard let view = makeImageView(image: image, format: VK_FORMAT_R8G8B8A8_UNORM, aspect: VK_IMAGE_ASPECT_COLOR_BIT)
    else { return nil }

    var setLayout: VkDescriptorSetLayout? = descriptorSetLayout
    var descriptorSet: VkDescriptorSet?
    let allocResult = withUnsafePointer(to: &setLayout) { layoutPtr -> VkResult in
      var allocInfo = VkDescriptorSetAllocateInfo()
      allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
      allocInfo.descriptorPool = descriptorPool
      allocInfo.descriptorSetCount = 1
      allocInfo.pSetLayouts = layoutPtr
      return vkAllocateDescriptorSets(device, &allocInfo, &descriptorSet)
    }
    guard allocResult == VK_SUCCESS, let descriptorSet else {
      log("Vulkan3DManager: vkAllocateDescriptorSets failed for \(path)")
      return nil
    }

    var imageInfo = VkDescriptorImageInfo(
      sampler: sampler, imageView: view, imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
    withUnsafePointer(to: imageInfo) { imageInfoPtr in
      var write = VkWriteDescriptorSet()
      write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
      write.dstSet = descriptorSet
      write.dstBinding = 0
      write.descriptorCount = 1
      write.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
      write.pImageInfo = imageInfoPtr
      vkUpdateDescriptorSets(device, 1, [write], 0, nil)
    }

    return GPUTexture(
      image: image, memory: memory, view: view, descriptorSet: descriptorSet,
      size: SIMD2<Float>(Float(width), Float(height)))
  }

  /// One-shot layout transition via a throwaway primary command buffer, submitted and waited on
  /// synchronously - only used a handful of times total (once per loaded texture, at level load),
  /// so simplicity wins over reusing/batching command buffers here.
  private func transitionImageLayout(image: VkImage, from oldLayout: VkImageLayout, to newLayout: VkImageLayout) {
    guard let device, let commandPool, let queue else { return }

    var allocInfo = VkCommandBufferAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    allocInfo.commandPool = commandPool
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
    allocInfo.commandBufferCount = 1
    var cmd: VkCommandBuffer?
    guard vkAllocateCommandBuffers(device, &allocInfo, &cmd) == VK_SUCCESS, let cmd else { return }
    defer { vkFreeCommandBuffers(device, commandPool, 1, [cmd]) }

    var beginInfo = VkCommandBufferBeginInfo()
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    beginInfo.flags = UInt32(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue)
    vkBeginCommandBuffer(cmd, &beginInfo)

    var barrier = VkImageMemoryBarrier()
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
    barrier.oldLayout = oldLayout
    barrier.newLayout = newLayout
    barrier.srcQueueFamilyIndex = UInt32(bitPattern: -1)  // VK_QUEUE_FAMILY_IGNORED
    barrier.dstQueueFamilyIndex = UInt32(bitPattern: -1)
    barrier.image = image
    barrier.subresourceRange = VkImageSubresourceRange(
      aspectMask: UInt32(VK_IMAGE_ASPECT_COLOR_BIT.rawValue), baseMipLevel: 0, levelCount: 1,
      baseArrayLayer: 0, layerCount: 1)
    barrier.srcAccessMask = 0
    barrier.dstAccessMask = UInt32(VK_ACCESS_SHADER_READ_BIT.rawValue)

    withUnsafePointer(to: barrier) { barrierPtr in
      vkCmdPipelineBarrier(
        cmd, UInt32(VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue),
        UInt32(VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT.rawValue), 0, 0, nil, 0, nil, 1, barrierPtr)
    }

    vkEndCommandBuffer(cmd)

    var cmdVar: VkCommandBuffer? = cmd
    withUnsafePointer(to: &cmdVar) { cmdPtr in
      var submitInfo = VkSubmitInfo()
      submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
      submitInfo.commandBufferCount = 1
      submitInfo.pCommandBuffers = cmdPtr
      vkQueueSubmit(queue, 1, &submitInfo, nil)
    }
    vkQueueWaitIdle(queue)
  }

  /// Resolves a sprite ID to its PNG the same way `Metal3DManager.swift`'s `spriteTexture` does
  /// (`spriteNameTable` -> search `backgroundsDirectory`/`backgroundsUndercoverDirectory`/
  /// `spritesDirectory`), caching per sprite ID.
  func spriteTexture(spriteID: Int32) -> GPUTexture? {
    if let cached = textureCache[spriteID] { return cached }
    guard spriteID >= 0, spriteID < spriteNameTable.count else { return nil }
    let staticName = spriteNameTable[Int(spriteID)]
    let name = staticName.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
    guard !name.isEmpty else { return nil }

    let directories = [backgroundsDirectory, backgroundsUndercoverDirectory, spritesDirectory]
    var foundPath: String?
    for directory in directories {
      let path = directory.appendingPathComponent("\(name).png").path
      if FileManager.default.fileExists(atPath: path) {
        foundPath = path
        break
      }
    }
    guard let path = foundPath, let texture = loadTextureFromDisk(path: path) else {
      log("Vulkan3DManager: failed to load sprite \(spriteID) (\(name))")
      return nil
    }
    textureCache[spriteID] = texture
    return texture
  }

  /// Junkbot's chest emblem, baked offline (see this file's doc comment) since Android has no
  /// `CoreGraphics` to rasterize it at runtime the way `Metal3DDecalTextures.swift` does.
  func loadJunkbotDecalTextureIfNeeded() -> GPUTexture? {
    if let junkbotDecalTexture { return junkbotDecalTexture }
    let path = repoRoot.appendingPathComponent("Models3D/junkbot_decal.png").path
    guard let texture = loadTextureFromDisk(path: path) else {
      log("Vulkan3DManager: failed to load junkbot_decal.png")
      return nil
    }
    junkbotDecalTexture = texture
    return texture
  }
}
