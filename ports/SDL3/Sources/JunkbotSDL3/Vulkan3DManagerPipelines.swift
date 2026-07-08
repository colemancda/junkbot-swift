// Pipeline/shader-module creation plus low-level Vulkan resource helpers (image/image-view/
// memory-type lookup) shared by setup and per-frame texture loading.

import CVulkan
import Foundation

extension Vulkan3DManager {
  /// Loads precompiled SPIR-V bytecode baked offline by `glslc` (see `ports/Android/Shaders/`'s
  /// `.vert`/`.frag` sources and this repo's "offline-bake, commit output" pattern) from the
  /// bundled `Shaders/<name>.spv` asset - same `repoRoot`-relative lookup every other asset
  /// (levels, images, `Models3D`) already uses, so it works unchanged whether `repoRoot` resolves
  /// to a Darwin bundle path or Android's `assetRootOverridePath`-extracted internal storage.
  private func loadShaderModule(named name: String) -> VkShaderModule? {
    guard let device else { return nil }
    let url = repoRoot.appendingPathComponent("Shaders/\(name).spv")
    guard let data = try? Data(contentsOf: url) else {
      log("Vulkan3DManager: missing shader \(url.path)")
      return nil
    }
    var module: VkShaderModule?
    let result = data.withUnsafeBytes { raw -> VkResult in
      var createInfo = VkShaderModuleCreateInfo()
      createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
      createInfo.codeSize = raw.count
      createInfo.pCode = raw.bindMemory(to: UInt32.self).baseAddress
      return vkCreateShaderModule(device, &createInfo, nil, &module)
    }
    guard result == VK_SUCCESS else {
      log("Vulkan3DManager: vkCreateShaderModule(\(name)) failed")
      return nil
    }
    return module
  }

  func createPipelines() -> Bool {
    guard let device, let renderPass else { return false }

    guard
      let mainVert = loadShaderModule(named: "vulkan3d.vert"),
      let mainFrag = loadShaderModule(named: "vulkan3d.frag"),
      let texVert = loadShaderModule(named: "backdrop.vert"),
      let texFrag = loadShaderModule(named: "backdrop.frag")
    else { return false }
    defer {
      vkDestroyShaderModule(device, mainVert, nil)
      vkDestroyShaderModule(device, mainFrag, nil)
      vkDestroyShaderModule(device, texVert, nil)
      vkDestroyShaderModule(device, texFrag, nil)
    }

    // Push-constant-only layout for the main entity/brick pipeline (one mat4 view-projection,
    // positions/normals already baked to world space on the CPU - see `Vulkan3DManager.swift`'s
    // doc comment, same approach `Metal3DManager.swift` uses) - no descriptor sets needed since it
    // never samples a texture.
    var pushConstantRange = VkPushConstantRange(
      stageFlags: UInt32(VK_SHADER_STAGE_VERTEX_BIT.rawValue), offset: 0,
      size: UInt32(MemoryLayout<float4x4>.size))
    var newMainLayout: VkPipelineLayout?
    let mainLayoutResult = withUnsafePointer(to: pushConstantRange) { rangePtr -> VkResult in
      var createInfo = VkPipelineLayoutCreateInfo()
      createInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
      createInfo.pushConstantRangeCount = 1
      createInfo.pPushConstantRanges = rangePtr
      return vkCreatePipelineLayout(device, &createInfo, nil, &newMainLayout)
    }
    guard mainLayoutResult == VK_SUCCESS, let newMainLayout else {
      log("Vulkan3DManager: main pipeline layout failed")
      return false
    }
    mainPipelineLayout = newMainLayout

    guard let descriptorSetLayout else { return false }
    var texturedSetLayout: VkDescriptorSetLayout? = descriptorSetLayout
    var newTexturedLayout: VkPipelineLayout?
    let texturedLayoutResult = withUnsafePointer(to: pushConstantRange) { rangePtr -> VkResult in
      withUnsafePointer(to: &texturedSetLayout) { setLayoutPtr -> VkResult in
        var createInfo = VkPipelineLayoutCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        createInfo.setLayoutCount = 1
        createInfo.pSetLayouts = setLayoutPtr
        createInfo.pushConstantRangeCount = 1
        createInfo.pPushConstantRanges = rangePtr
        return vkCreatePipelineLayout(device, &createInfo, nil, &newTexturedLayout)
      }
    }
    guard texturedLayoutResult == VK_SUCCESS, let newTexturedLayout else {
      log("Vulkan3DManager: textured pipeline layout failed")
      return false
    }
    texturedPipelineLayout = newTexturedLayout

    // `Metal3DVertex`: position(vec3)@0, normal(vec3)@16, color(vec4)@32, matching
    // `Metal3DShaderSource`'s `VertexIn`/`vulkan3d.vert`'s `inPosition`/`inNormal`/`inColor`.
    var mainAttrs = [
      VkVertexInputAttributeDescription(location: 0, binding: 0, format: VK_FORMAT_R32G32B32_SFLOAT, offset: 0),
      VkVertexInputAttributeDescription(location: 1, binding: 0, format: VK_FORMAT_R32G32B32_SFLOAT, offset: 16),
      VkVertexInputAttributeDescription(location: 2, binding: 0, format: VK_FORMAT_R32G32B32A32_SFLOAT, offset: 32),
    ]
    var mainBinding = VkVertexInputBindingDescription(
      binding: 0, stride: UInt32(MemoryLayout<Metal3DVertex>.stride), inputRate: VK_VERTEX_INPUT_RATE_VERTEX)

    // `TexturedVertex`: position(vec3)@0, uv(vec2)@16, matching `backdrop.vert`'s
    // `inPosition`/`inUV`.
    var texturedAttrs = [
      VkVertexInputAttributeDescription(location: 0, binding: 0, format: VK_FORMAT_R32G32B32_SFLOAT, offset: 0),
      VkVertexInputAttributeDescription(location: 1, binding: 0, format: VK_FORMAT_R32G32_SFLOAT, offset: 16),
    ]
    var texturedBinding = VkVertexInputBindingDescription(
      binding: 0, stride: UInt32(MemoryLayout<TexturedVertex>.stride),
      inputRate: VK_VERTEX_INPUT_RATE_VERTEX)

    var mainDepth = VkPipelineDepthStencilStateCreateInfo()
    mainDepth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
    mainDepth.depthTestEnable = VkBool32(1)
    mainDepth.depthWriteEnable = VkBool32(1)
    mainDepth.depthCompareOp = VK_COMPARE_OP_LESS

    // Backdrop + background/foreground decal layers: always draw, never write depth (matches
    // `Metal3DManager.swift`'s `backdropDepthState`).
    var alwaysDepth = VkPipelineDepthStencilStateCreateInfo()
    alwaysDepth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
    alwaysDepth.depthTestEnable = VkBool32(1)
    alwaysDepth.depthWriteEnable = VkBool32(0)
    alwaysDepth.depthCompareOp = VK_COMPARE_OP_ALWAYS

    // Chest emblem: test depth (occluded by anything genuinely in front) but don't write it -
    // matches `Metal3DManager.swift`'s `decalDepthState`.
    var lessEqualDepth = VkPipelineDepthStencilStateCreateInfo()
    lessEqualDepth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
    lessEqualDepth.depthTestEnable = VkBool32(1)
    lessEqualDepth.depthWriteEnable = VkBool32(0)
    lessEqualDepth.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL

    mainPipeline = makePipeline(
      vert: mainVert, frag: mainFrag, attrs: &mainAttrs, binding: &mainBinding,
      layout: newMainLayout, depthStencil: mainDepth, blend: false)
    texturedPipelineAlways = makePipeline(
      vert: texVert, frag: texFrag, attrs: &texturedAttrs, binding: &texturedBinding,
      layout: newTexturedLayout, depthStencil: alwaysDepth, blend: true)
    texturedPipelineLessEqual = makePipeline(
      vert: texVert, frag: texFrag, attrs: &texturedAttrs, binding: &texturedBinding,
      layout: newTexturedLayout, depthStencil: lessEqualDepth, blend: true)

    return mainPipeline != nil && texturedPipelineAlways != nil && texturedPipelineLessEqual != nil
  }

  private func makePipeline(
    vert: VkShaderModule, frag: VkShaderModule,
    attrs: inout [VkVertexInputAttributeDescription],
    binding: inout VkVertexInputBindingDescription, layout: VkPipelineLayout,
    depthStencil: VkPipelineDepthStencilStateCreateInfo, blend: Bool
  ) -> VkPipeline? {
    guard let device, let renderPass else { return nil }

    let entryPoint = "main"
    return entryPoint.withCString { entryPointPtr -> VkPipeline? in
      var vertStage = VkPipelineShaderStageCreateInfo()
      vertStage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
      vertStage.stage = VK_SHADER_STAGE_VERTEX_BIT
      vertStage.module = vert
      vertStage.pName = entryPointPtr

      var fragStage = VkPipelineShaderStageCreateInfo()
      fragStage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
      fragStage.stage = VK_SHADER_STAGE_FRAGMENT_BIT
      fragStage.module = frag
      fragStage.pName = entryPointPtr

      let stages = [vertStage, fragStage]

      return stages.withUnsafeBufferPointer { stagesBuf -> VkPipeline? in
        attrs.withUnsafeBufferPointer { attrsBuf -> VkPipeline? in
          withUnsafePointer(to: binding) { bindingPtr -> VkPipeline? in
            var vertexInput = VkPipelineVertexInputStateCreateInfo()
            vertexInput.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
            vertexInput.vertexBindingDescriptionCount = 1
            vertexInput.pVertexBindingDescriptions = bindingPtr
            vertexInput.vertexAttributeDescriptionCount = UInt32(attrsBuf.count)
            vertexInput.pVertexAttributeDescriptions = attrsBuf.baseAddress

            var inputAssembly = VkPipelineInputAssemblyStateCreateInfo()
            inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
            inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST

            var viewport = VkViewport(
              x: 0, y: 0, width: Float(swapchainExtent.width), height: Float(swapchainExtent.height),
              minDepth: 0, maxDepth: 1)
            var scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapchainExtent)
            var viewportState = VkPipelineViewportStateCreateInfo()
            viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
            viewportState.viewportCount = 1
            viewportState.pViewports = withUnsafePointer(to: &viewport) { $0 }
            viewportState.scissorCount = 1
            viewportState.pScissors = withUnsafePointer(to: &scissor) { $0 }

            var rasterizer = VkPipelineRasterizationStateCreateInfo()
            rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
            rasterizer.polygonMode = VK_POLYGON_MODE_FILL
            // No culling, matching `Metal3DManager.swift`'s pipelines (never sets a cull mode) -
            // this renderer never establishes a consistent winding order for baked LDraw geometry.
            rasterizer.cullMode = UInt32(VK_CULL_MODE_NONE.rawValue)
            rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE
            rasterizer.lineWidth = 1

            var multisampling = VkPipelineMultisampleStateCreateInfo()
            multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
            multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT

            var colorBlendAttachment = VkPipelineColorBlendAttachmentState()
            colorBlendAttachment.colorWriteMask =
              UInt32(VK_COLOR_COMPONENT_R_BIT.rawValue) | UInt32(VK_COLOR_COMPONENT_G_BIT.rawValue)
              | UInt32(VK_COLOR_COMPONENT_B_BIT.rawValue) | UInt32(VK_COLOR_COMPONENT_A_BIT.rawValue)
            if blend {
              colorBlendAttachment.blendEnable = VkBool32(1)
              colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA
              colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
              colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD
              colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE
              colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
              colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD
            }
            var colorBlending = VkPipelineColorBlendStateCreateInfo()
            colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
            colorBlending.attachmentCount = 1
            colorBlending.pAttachments = withUnsafePointer(to: &colorBlendAttachment) { $0 }

            var depthStencilVar = depthStencil

            var pipeline: VkPipeline?
            let result = withUnsafePointer(to: &depthStencilVar) { depthPtr -> VkResult in
              var pipelineInfo = VkGraphicsPipelineCreateInfo()
              pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
              pipelineInfo.stageCount = 2
              pipelineInfo.pStages = stagesBuf.baseAddress
              pipelineInfo.pVertexInputState = withUnsafePointer(to: &vertexInput) { $0 }
              pipelineInfo.pInputAssemblyState = withUnsafePointer(to: &inputAssembly) { $0 }
              pipelineInfo.pViewportState = withUnsafePointer(to: &viewportState) { $0 }
              pipelineInfo.pRasterizationState = withUnsafePointer(to: &rasterizer) { $0 }
              pipelineInfo.pMultisampleState = withUnsafePointer(to: &multisampling) { $0 }
              pipelineInfo.pColorBlendState = withUnsafePointer(to: &colorBlending) { $0 }
              pipelineInfo.pDepthStencilState = depthPtr
              pipelineInfo.layout = layout
              pipelineInfo.renderPass = renderPass
              pipelineInfo.subpass = 0
              return vkCreateGraphicsPipelines(device, nil, 1, &pipelineInfo, nil, &pipeline)
            }
            guard result == VK_SUCCESS else {
              log("Vulkan3DManager: vkCreateGraphicsPipelines failed (\(result.rawValue))")
              return nil
            }
            return pipeline
          }
        }
      }
    }
  }

  // MARK: - Low-level resource helpers

  func findMemoryType(typeBits: UInt32, properties: UInt32) -> UInt32? {
    guard let physicalDevice else { return nil }
    var memProperties = VkPhysicalDeviceMemoryProperties()
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties)
    for i in 0..<Int(memProperties.memoryTypeCount) {
      let type = withUnsafeBytes(of: memProperties.memoryTypes) { raw -> VkMemoryType in
        raw.bindMemory(to: VkMemoryType.self)[i]
      }
      let matches = (typeBits & (1 << UInt32(i))) != 0
      let hasProperties = (type.propertyFlags & properties) == properties
      if matches && hasProperties { return UInt32(i) }
    }
    return nil
  }

  func makeImage(
    width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: UInt32,
    properties: UInt32
  ) -> (VkImage, VkDeviceMemory)? {
    guard let device else { return nil }
    var imageInfo = VkImageCreateInfo()
    imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
    imageInfo.imageType = VK_IMAGE_TYPE_2D
    imageInfo.extent = VkExtent3D(width: width, height: height, depth: 1)
    imageInfo.mipLevels = 1
    imageInfo.arrayLayers = 1
    imageInfo.format = format
    imageInfo.tiling = tiling
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    imageInfo.usage = usage
    imageInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE
    imageInfo.samples = VK_SAMPLE_COUNT_1_BIT

    var image: VkImage?
    guard vkCreateImage(device, &imageInfo, nil, &image) == VK_SUCCESS, let image else {
      log("Vulkan3DManager: vkCreateImage failed")
      return nil
    }

    var requirements = VkMemoryRequirements()
    vkGetImageMemoryRequirements(device, image, &requirements)
    guard let memoryTypeIndex = findMemoryType(typeBits: requirements.memoryTypeBits, properties: properties)
    else {
      log("Vulkan3DManager: no suitable memory type for image")
      return nil
    }

    var allocInfo = VkMemoryAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
    allocInfo.allocationSize = requirements.size
    allocInfo.memoryTypeIndex = memoryTypeIndex
    var memory: VkDeviceMemory?
    guard vkAllocateMemory(device, &allocInfo, nil, &memory) == VK_SUCCESS, let memory else {
      log("Vulkan3DManager: vkAllocateMemory (image) failed")
      return nil
    }
    vkBindImageMemory(device, image, memory, 0)
    return (image, memory)
  }

  func makeImageView(image: VkImage, format: VkFormat, aspect: VkImageAspectFlagBits) -> VkImageView? {
    guard let device else { return nil }
    var createInfo = VkImageViewCreateInfo()
    createInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
    createInfo.image = image
    createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
    createInfo.format = format
    createInfo.subresourceRange = VkImageSubresourceRange(
      aspectMask: UInt32(aspect.rawValue), baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0,
      layerCount: 1)
    var view: VkImageView?
    guard vkCreateImageView(device, &createInfo, nil, &view) == VK_SUCCESS else {
      log("Vulkan3DManager: vkCreateImageView failed")
      return nil
    }
    return view
  }
}
