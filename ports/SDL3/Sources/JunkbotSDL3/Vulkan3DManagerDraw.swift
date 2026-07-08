// Per-frame recording/submission for `Vulkan3DManager` - counterpart of `Metal3DManager.swift`'s
// `draw(in:)`. Single frame in flight (fence-gated), one combined vertex buffer rebuilt and
// re-uploaded every frame - see `Vulkan3DManager.swift`'s doc comment for why.

import CVulkan

extension Vulkan3DManager {
  /// Call once per rendered frame (mirrors `Metal3DManager.draw(in:)`, invoked from
  /// `MTKViewDelegate.draw(in:)` there; here the caller drives it directly from the game loop -
  /// see `AndroidMain.swift`'s per-frame hook).
  func draw() {
    guard
      let device, let swapchain, let renderPass, let commandBuffer,
      let imageAvailableSemaphore, let renderFinishedSemaphore, let inFlightFence, let queue
    else { return }

    var fence: VkFence? = inFlightFence
    withUnsafePointer(to: &fence) { vkWaitForFences(device, 1, $0, VkBool32(1), UInt64.max) }
    withUnsafePointer(to: &fence) { _ = vkResetFences(device, 1, $0) }

    var imageIndex: UInt32 = 0
    let acquireResult = vkAcquireNextImageKHR(
      device, swapchain, UInt64.max, imageAvailableSemaphore, nil, &imageIndex)
    guard acquireResult == VK_SUCCESS || acquireResult == VK_SUBOPTIMAL_KHR else {
      // VK_ERROR_OUT_OF_DATE_KHR (window resized) - swapchain recreation isn't implemented (this
      // renderer targets a fixed-orientation, effectively fixed-size Android window the same way
      // every other port's `.aspectFit`-scaled fixed logical canvas does); just skip the frame.
      return
    }

    updateVertexBuffer()

    vkResetCommandBuffer(commandBuffer, 0)
    var beginInfo = VkCommandBufferBeginInfo()
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
    vkBeginCommandBuffer(commandBuffer, &beginInfo)

    var clearValues = [VkClearValue](repeating: VkClearValue(), count: 2)
    clearValues[0].color.float32 = (0, 0, 0, 1)
    clearValues[1].depthStencil = VkClearDepthStencilValue(depth: 1, stencil: 0)

    clearValues.withUnsafeBufferPointer { clearBuf in
      var renderPassInfo = VkRenderPassBeginInfo()
      renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
      renderPassInfo.renderPass = renderPass
      renderPassInfo.framebuffer = framebuffers[Int(imageIndex)]
      renderPassInfo.renderArea = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapchainExtent)
      renderPassInfo.clearValueCount = 2
      renderPassInfo.pClearValues = clearBuf.baseAddress
      vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE)
    }

    if let backdropTexture {
      drawTexturedQuad(
        pipeline: texturedPipelineAlways, texture: backdropTexture,
        transform: Metal3DMatrix.translation(backdropWorldPosition), halfWidth: backdropTexture.size.x / 2,
        halfHeight: backdropTexture.size.y / 2)
    }
    for quad in backgroundDecalQuads {
      drawTexturedQuad(
        pipeline: texturedPipelineAlways, texture: quad.texture,
        transform: Metal3DMatrix.translation(quad.worldPosition), halfWidth: quad.texture.size.x / 2,
        halfHeight: quad.texture.size.y / 2)
    }
    for quad in foregroundDecalQuads {
      drawTexturedQuad(
        pipeline: texturedPipelineAlways, texture: quad.texture,
        transform: Metal3DMatrix.translation(quad.worldPosition), halfWidth: quad.texture.size.x / 2,
        halfHeight: quad.texture.size.y / 2)
    }

    if !combinedVertices.isEmpty, let mainPipeline, let mainPipelineLayout, let vertexBuffer {
      vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, mainPipeline)
      var offset: VkDeviceSize = 0
      var buffer: VkBuffer? = vertexBuffer
      withUnsafePointer(to: &buffer) { bufferPtr in
        vkCmdBindVertexBuffers(commandBuffer, 0, 1, bufferPtr, &offset)
      }
      var mvp = viewProjection
      withUnsafePointer(to: &mvp) { mvpPtr in
        vkCmdPushConstants(
          commandBuffer, mainPipelineLayout, UInt32(VK_SHADER_STAGE_VERTEX_BIT.rawValue), 0,
          UInt32(MemoryLayout<float4x4>.size), mvpPtr)
      }
      vkCmdDraw(commandBuffer, UInt32(combinedVertices.count), 1, 0, 0)
    }

    if !pendingDecalQuads.isEmpty, let texture = loadJunkbotDecalTextureIfNeeded() {
      for quad in pendingDecalQuads {
        drawTexturedQuad(
          pipeline: texturedPipelineLessEqual, texture: texture, transform: quad.transform,
          halfWidth: quad.halfWidth, halfHeight: quad.halfHeight)
      }
    }

    vkCmdEndRenderPass(commandBuffer)
    vkEndCommandBuffer(commandBuffer)

    var waitSemaphore: VkSemaphore? = imageAvailableSemaphore
    var signalSemaphore: VkSemaphore? = renderFinishedSemaphore
    var cmdBufferVar: VkCommandBuffer? = commandBuffer
    var waitStage = VkPipelineStageFlags(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)

    withUnsafePointer(to: &waitSemaphore) { waitSemPtr in
      withUnsafePointer(to: &signalSemaphore) { signalSemPtr in
        withUnsafePointer(to: &cmdBufferVar) { cmdPtr in
          withUnsafePointer(to: &waitStage) { waitStagePtr in
            var submitInfo = VkSubmitInfo()
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
            submitInfo.waitSemaphoreCount = 1
            submitInfo.pWaitSemaphores = waitSemPtr
            submitInfo.pWaitDstStageMask = waitStagePtr
            submitInfo.commandBufferCount = 1
            submitInfo.pCommandBuffers = cmdPtr
            submitInfo.signalSemaphoreCount = 1
            submitInfo.pSignalSemaphores = signalSemPtr
            vkQueueSubmit(queue, 1, &submitInfo, inFlightFence)
          }
        }
      }
    }

    var swapchainVar: VkSwapchainKHR? = swapchain
    var imageIndexVar = imageIndex
    withUnsafePointer(to: &signalSemaphore) { signalSemPtr in
      withUnsafePointer(to: &swapchainVar) { swapchainPtr in
        withUnsafePointer(to: &imageIndexVar) { imageIndexPtr in
          var presentInfo = VkPresentInfoKHR()
          presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
          presentInfo.waitSemaphoreCount = 1
          presentInfo.pWaitSemaphores = signalSemPtr
          presentInfo.swapchainCount = 1
          presentInfo.pSwapchains = swapchainPtr
          presentInfo.pImageIndices = imageIndexPtr
          vkQueuePresentKHR(queue, &presentInfo)
        }
      }
    }
  }

  private func updateVertexBuffer() {
    guard let device, !combinedVertices.isEmpty else { return }
    let byteCount = combinedVertices.count * MemoryLayout<Metal3DVertex>.stride
    if vertexBuffer == nil || vertexBufferCapacityBytes < byteCount {
      if let vertexBuffer { vkDestroyBuffer(device, vertexBuffer, nil) }
      if let vertexBufferMemory { vkFreeMemory(device, vertexBufferMemory, nil) }
      guard
        let (buffer, memory) = makeBuffer(
          size: VkDeviceSize(byteCount), usage: UInt32(VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue),
          properties: UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
            | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue))
      else { return }
      vertexBuffer = buffer
      vertexBufferMemory = memory
      vertexBufferCapacityBytes = byteCount
    }
    guard let vertexBufferMemory else { return }
    var mapped: UnsafeMutableRawPointer?
    vkMapMemory(device, vertexBufferMemory, 0, VkDeviceSize(byteCount), 0, &mapped)
    if let mapped {
      combinedVertices.withUnsafeBytes { raw in
        mapped.copyMemory(from: raw.baseAddress!, byteCount: raw.count)
      }
    }
    vkUnmapMemory(device, vertexBufferMemory)
  }

  func makeBuffer(size: VkDeviceSize, usage: UInt32, properties: UInt32) -> (VkBuffer, VkDeviceMemory)? {
    guard let device else { return nil }
    var bufferInfo = VkBufferCreateInfo()
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
    bufferInfo.size = size
    bufferInfo.usage = usage
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE
    var buffer: VkBuffer?
    guard vkCreateBuffer(device, &bufferInfo, nil, &buffer) == VK_SUCCESS, let buffer else {
      log("Vulkan3DManager: vkCreateBuffer failed")
      return nil
    }

    var requirements = VkMemoryRequirements()
    vkGetBufferMemoryRequirements(device, buffer, &requirements)
    guard let memoryTypeIndex = findMemoryType(typeBits: requirements.memoryTypeBits, properties: properties)
    else {
      log("Vulkan3DManager: no suitable memory type for buffer")
      return nil
    }
    var allocInfo = VkMemoryAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
    allocInfo.allocationSize = requirements.size
    allocInfo.memoryTypeIndex = memoryTypeIndex
    var memory: VkDeviceMemory?
    guard vkAllocateMemory(device, &allocInfo, nil, &memory) == VK_SUCCESS, let memory else {
      log("Vulkan3DManager: vkAllocateMemory (buffer) failed")
      return nil
    }
    vkBindBufferMemory(device, buffer, memory, 0)
    return (buffer, memory)
  }

  /// Draws a `halfWidth`x`halfHeight` quad in `transform`'s local XY plane - counterpart of
  /// `Metal3DManager.swift`'s `drawTexturedQuad`. `pipeline` picks the depth behavior (always,
  /// for the backdrop/decal layers; less-equal, for the chest emblem - see
  /// `Vulkan3DManager.swift`'s doc comment).
  private func drawTexturedQuad(
    pipeline: VkPipeline?, texture: GPUTexture, transform: float4x4, halfWidth: Float, halfHeight: Float
  ) {
    guard
      let commandBuffer, let pipeline, let texturedPipelineLayout, let descriptorSet = texture.descriptorSet
    else { return }

    func corner(_ x: Float, _ y: Float) -> SIMD3<Float> {
      let p = transform * SIMD4<Float>(x, y, 0, 1)
      return SIMD3<Float>(p.x, p.y, p.z)
    }
    let c00 = corner(-halfWidth, -halfHeight)
    let c10 = corner(halfWidth, -halfHeight)
    let c11 = corner(halfWidth, halfHeight)
    let c01 = corner(-halfWidth, halfHeight)
    let quad: [TexturedVertex] = [
      .init(position: c00, uv: SIMD2(0, 1)),
      .init(position: c10, uv: SIMD2(1, 1)),
      .init(position: c11, uv: SIMD2(1, 0)),
      .init(position: c00, uv: SIMD2(0, 1)),
      .init(position: c11, uv: SIMD2(1, 0)),
      .init(position: c01, uv: SIMD2(0, 0)),
    ]

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline)
    var descriptorSetVar: VkDescriptorSet? = descriptorSet
    withUnsafePointer(to: &descriptorSetVar) { setPtr in
      vkCmdBindDescriptorSets(
        commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, texturedPipelineLayout, 0, 1, setPtr, 0, nil)
    }
    var mvp = viewProjection
    withUnsafePointer(to: &mvp) { mvpPtr in
      vkCmdPushConstants(
        commandBuffer, texturedPipelineLayout, UInt32(VK_SHADER_STAGE_VERTEX_BIT.rawValue), 0,
        UInt32(MemoryLayout<float4x4>.size), mvpPtr)
    }
    // Tiny (6-vertex) per-draw quad - pushed via a throwaway host-visible buffer each call rather
    // than threading a persistent one through, matching this file's "simplicity over
    // micro-optimizing rarely-hot paths" stance (backdrop + a handful of decals per frame, not a
    // tight loop).
    guard
      let (quadBuffer, quadMemory) = makeBuffer(
        size: VkDeviceSize(quad.count * MemoryLayout<TexturedVertex>.stride),
        usage: UInt32(VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue),
        properties: UInt32(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
          | UInt32(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue))
    else { return }
    defer {
      if let device {
        vkDestroyBuffer(device, quadBuffer, nil)
        vkFreeMemory(device, quadMemory, nil)
      }
    }
    if let device {
      var mapped: UnsafeMutableRawPointer?
      vkMapMemory(device, quadMemory, 0, VK_WHOLE_SIZE, 0, &mapped)
      if let mapped {
        quad.withUnsafeBytes { raw in mapped.copyMemory(from: raw.baseAddress!, byteCount: raw.count) }
      }
      vkUnmapMemory(device, quadMemory)
    }

    var offset: VkDeviceSize = 0
    var buffer: VkBuffer? = quadBuffer
    withUnsafePointer(to: &buffer) { bufferPtr in
      vkCmdBindVertexBuffers(commandBuffer, 0, 1, bufferPtr, &offset)
    }
    vkCmdDraw(commandBuffer, UInt32(quad.count), 1, 0, 0)
  }
}
