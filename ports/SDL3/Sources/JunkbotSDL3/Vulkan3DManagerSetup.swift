// One-time Vulkan object setup for `Vulkan3DManager` - instance/device/swapchain/render-
// pass/pipelines/sync objects. Split from `Vulkan3DManager.swift` (which holds per-frame
// scene/draw logic) purely to keep each file a manageable size; both extend the same class.

import CSDL3
import CVulkan
import Foundation

extension Vulkan3DManager {
  func createInstance() -> Bool {
    var extensionCount: UInt32 = 0
    guard let rawExtensions = SDL_Vulkan_GetInstanceExtensions(&extensionCount) else {
      log("Vulkan3DManager: SDL_Vulkan_GetInstanceExtensions failed")
      return false
    }

    var newInstance: VkInstance?
    let result = "Junkbot".withCString { namePtr -> VkResult in
      var appInfo = VkApplicationInfo()
      appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
      appInfo.pApplicationName = namePtr
      appInfo.applicationVersion = 1
      appInfo.pEngineName = namePtr
      appInfo.engineVersion = 1
      // `VK_MAKE_API_VERSION(0, 1, 1, 0)` - a C macro, not imported as a callable Swift function -
      // expanded by hand: `(variant<<29)|(major<<22)|(minor<<12)|patch`.
      appInfo.apiVersion = (1 << 22) | (1 << 12)

      return withUnsafePointer(to: appInfo) { appInfoPtr -> VkResult in
        var createInfo = VkInstanceCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        createInfo.pApplicationInfo = appInfoPtr
        createInfo.enabledExtensionCount = extensionCount
        createInfo.ppEnabledExtensionNames = rawExtensions
        return vkCreateInstance(&createInfo, nil, &newInstance)
      }
    }
    guard result == VK_SUCCESS, let newInstance else {
      log("Vulkan3DManager: vkCreateInstance failed (\(result.rawValue))")
      return false
    }
    instance = newInstance
    return true
  }

  func createSurface() -> Bool {
    guard let instance else { return false }
    var newSurface: VkSurfaceKHR?
    guard SDL_Vulkan_CreateSurface(sdlWindow, instance, nil, &newSurface), let newSurface else {
      log("Vulkan3DManager: SDL_Vulkan_CreateSurface failed")
      return false
    }
    surface = newSurface
    return true
  }

  func pickPhysicalDeviceAndQueue() -> Bool {
    guard let instance, let surface else { return false }

    var deviceCount: UInt32 = 0
    vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
    guard deviceCount > 0 else {
      log("Vulkan3DManager: no Vulkan physical devices")
      return false
    }
    var devices = [VkPhysicalDevice?](repeating: nil, count: Int(deviceCount))
    vkEnumeratePhysicalDevices(instance, &deviceCount, &devices)

    for candidate in devices {
      guard let candidate else { continue }
      var queueFamilyCount: UInt32 = 0
      vkGetPhysicalDeviceQueueFamilyProperties(candidate, &queueFamilyCount, nil)
      var families = [VkQueueFamilyProperties](
        repeating: VkQueueFamilyProperties(), count: Int(queueFamilyCount))
      vkGetPhysicalDeviceQueueFamilyProperties(candidate, &queueFamilyCount, &families)

      for (index, family) in families.enumerated() {
        let isGraphics = (family.queueFlags & UInt32(VK_QUEUE_GRAPHICS_BIT.rawValue)) != 0
        var presentSupport: VkBool32 = 0
        vkGetPhysicalDeviceSurfaceSupportKHR(candidate, UInt32(index), surface, &presentSupport)
        if isGraphics && presentSupport != 0 {
          physicalDevice = candidate
          queueFamilyIndex = UInt32(index)
          return true
        }
      }
    }
    log("Vulkan3DManager: no physical device with a combined graphics+present queue")
    return false
  }

  func createLogicalDevice() -> Bool {
    guard let physicalDevice else { return false }

    var queuePriority: Float = 1.0
    var queueCreateInfo = VkDeviceQueueCreateInfo()
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    queueCreateInfo.queueFamilyIndex = queueFamilyIndex
    queueCreateInfo.queueCount = 1
    queueCreateInfo.pQueuePriorities = withUnsafePointer(to: &queuePriority) { $0 }

    let swapchainExtensionName = "VK_KHR_swapchain"
    return swapchainExtensionName.withCString { extNamePtr -> Bool in
      let extNames: [UnsafePointer<CChar>?] = [extNamePtr]
      var newDevice: VkDevice?
      let result = extNames.withUnsafeBufferPointer { extNamesBuf -> VkResult in
        withUnsafePointer(to: queueCreateInfo) { queueInfoPtr -> VkResult in
          var createInfo = VkDeviceCreateInfo()
          createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
          createInfo.queueCreateInfoCount = 1
          createInfo.pQueueCreateInfos = queueInfoPtr
          createInfo.enabledExtensionCount = 1
          createInfo.ppEnabledExtensionNames = extNamesBuf.baseAddress
          return vkCreateDevice(physicalDevice, &createInfo, nil, &newDevice)
        }
      }
      guard result == VK_SUCCESS, let newDevice else {
        log("Vulkan3DManager: vkCreateDevice failed (\(result.rawValue))")
        return false
      }
      device = newDevice
      var newQueue: VkQueue?
      vkGetDeviceQueue(newDevice, queueFamilyIndex, 0, &newQueue)
      queue = newQueue
      return true
    }
  }

  func createSwapchain() -> Bool {
    guard let physicalDevice, let device, let surface else { return false }

    var capabilities = VkSurfaceCapabilitiesKHR()
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &capabilities)

    var formatCount: UInt32 = 0
    vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, nil)
    var formats = [VkSurfaceFormatKHR](repeating: VkSurfaceFormatKHR(), count: Int(formatCount))
    vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, &formats)
    let chosenFormat =
      formats.first {
        $0.format == VK_FORMAT_B8G8R8A8_UNORM
          && $0.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
      } ?? formats.first ?? VkSurfaceFormatKHR(format: VK_FORMAT_B8G8R8A8_UNORM, colorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
    swapchainFormat = chosenFormat.format

    // FIFO is the one present mode every conformant Vulkan implementation must support - matches
    // this project's "simplicity over performance" precedent rather than opportunistically
    // picking MAILBOX for lower latency.
    let presentMode = VK_PRESENT_MODE_FIFO_KHR

    let extent: VkExtent2D
    if capabilities.currentExtent.width != UInt32.max {
      extent = capabilities.currentExtent
    } else {
      var w: Int32 = 0
      var h: Int32 = 0
      SDL_GetWindowSizeInPixels(sdlWindow, &w, &h)
      extent = VkExtent2D(
        width: UInt32(
          max(
            capabilities.minImageExtent.width,
            min(capabilities.maxImageExtent.width, UInt32(max(w, 1))))),
        height: UInt32(
          max(
            capabilities.minImageExtent.height,
            min(capabilities.maxImageExtent.height, UInt32(max(h, 1))))))
    }
    swapchainExtent = extent

    var imageCount = capabilities.minImageCount + 1
    if capabilities.maxImageCount > 0 {
      imageCount = min(imageCount, capabilities.maxImageCount)
    }

    var createInfo = VkSwapchainCreateInfoKHR()
    createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    createInfo.surface = surface
    createInfo.minImageCount = imageCount
    createInfo.imageFormat = chosenFormat.format
    createInfo.imageColorSpace = chosenFormat.colorSpace
    createInfo.imageExtent = extent
    createInfo.imageArrayLayers = 1
    createInfo.imageUsage = UInt32(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue)
    createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
    createInfo.preTransform = capabilities.currentTransform
    createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
    createInfo.presentMode = presentMode
    createInfo.clipped = VkBool32(1)

    var newSwapchain: VkSwapchainKHR?
    guard vkCreateSwapchainKHR(device, &createInfo, nil, &newSwapchain) == VK_SUCCESS,
      let newSwapchain
    else {
      log("Vulkan3DManager: vkCreateSwapchainKHR failed")
      return false
    }
    swapchain = newSwapchain

    var actualImageCount: UInt32 = 0
    vkGetSwapchainImagesKHR(device, newSwapchain, &actualImageCount, nil)
    var images = [VkImage?](repeating: nil, count: Int(actualImageCount))
    vkGetSwapchainImagesKHR(device, newSwapchain, &actualImageCount, &images)

    swapchainImageViews = images.map { image -> VkImageView? in
      guard let image else { return nil }
      return makeImageView(
        image: image, format: swapchainFormat, aspect: VK_IMAGE_ASPECT_COLOR_BIT)
    }
    return swapchainImageViews.allSatisfy { $0 != nil }
  }

  func createRenderPass() -> Bool {
    guard let device else { return false }

    var colorAttachment = VkAttachmentDescription()
    colorAttachment.format = swapchainFormat
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

    var depthAttachment = VkAttachmentDescription()
    depthAttachment.format = VK_FORMAT_D32_SFLOAT
    depthAttachment.samples = VK_SAMPLE_COUNT_1_BIT
    depthAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
    depthAttachment.storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    depthAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
    depthAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
    depthAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
    depthAttachment.finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL

    var colorRef = VkAttachmentReference(
      attachment: 0, layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
    var depthRef = VkAttachmentReference(
      attachment: 1, layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL)

    var subpass = VkSubpassDescription()
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
    subpass.colorAttachmentCount = 1
    subpass.pColorAttachments = withUnsafePointer(to: &colorRef) { $0 }
    subpass.pDepthStencilAttachment = withUnsafePointer(to: &depthRef) { $0 }

    var dependency = VkSubpassDependency()
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL
    dependency.dstSubpass = 0
    dependency.srcStageMask =
      UInt32(VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue)
      | UInt32(VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT.rawValue)
    dependency.dstStageMask = dependency.srcStageMask
    dependency.srcAccessMask = 0
    dependency.dstAccessMask =
      UInt32(VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.rawValue)
      | UInt32(VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT.rawValue)

    let attachments = [colorAttachment, depthAttachment]
    var newRenderPass: VkRenderPass?
    let result = attachments.withUnsafeBufferPointer { attachmentsBuf -> VkResult in
      withUnsafePointer(to: subpass) { subpassPtr -> VkResult in
        withUnsafePointer(to: dependency) { depPtr -> VkResult in
          var createInfo = VkRenderPassCreateInfo()
          createInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
          createInfo.attachmentCount = 2
          createInfo.pAttachments = attachmentsBuf.baseAddress
          createInfo.subpassCount = 1
          createInfo.pSubpasses = subpassPtr
          createInfo.dependencyCount = 1
          createInfo.pDependencies = depPtr
          return vkCreateRenderPass(device, &createInfo, nil, &newRenderPass)
        }
      }
    }
    guard result == VK_SUCCESS, let newRenderPass else {
      log("Vulkan3DManager: vkCreateRenderPass failed")
      return false
    }
    renderPass = newRenderPass
    return true
  }

  func createDepthResources() -> Bool {
    guard let device else { return false }
    guard
      let (image, memory) = makeImage(
        width: swapchainExtent.width, height: swapchainExtent.height, format: VK_FORMAT_D32_SFLOAT,
        tiling: VK_IMAGE_TILING_OPTIMAL,
        usage: UInt32(VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT.rawValue),
        properties: UInt32(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue))
    else {
      log("Vulkan3DManager: depth image creation failed")
      return false
    }
    depthImage = image
    depthImageMemory = memory
    depthImageView = makeImageView(image: image, format: VK_FORMAT_D32_SFLOAT, aspect: VK_IMAGE_ASPECT_DEPTH_BIT)
    _ = device
    return depthImageView != nil
  }

  func createFramebuffers() -> Bool {
    guard let device, let renderPass, let depthImageView else { return false }
    framebuffers = swapchainImageViews.map { colorView -> VkFramebuffer? in
      guard let colorView else { return nil }
      let attachments: [VkImageView?] = [colorView, depthImageView]
      var newFramebuffer: VkFramebuffer?
      let result = attachments.withUnsafeBufferPointer { attachmentsBuf -> VkResult in
        var createInfo = VkFramebufferCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
        createInfo.renderPass = renderPass
        createInfo.attachmentCount = 2
        createInfo.pAttachments = attachmentsBuf.baseAddress
        createInfo.width = swapchainExtent.width
        createInfo.height = swapchainExtent.height
        createInfo.layers = 1
        return vkCreateFramebuffer(device, &createInfo, nil, &newFramebuffer)
      }
      return result == VK_SUCCESS ? newFramebuffer : nil
    }
    return framebuffers.allSatisfy { $0 != nil }
  }

  func createCommandPoolAndBuffer() -> Bool {
    guard let device else { return false }
    var poolInfo = VkCommandPoolCreateInfo()
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
    poolInfo.flags = UInt32(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.rawValue)
    poolInfo.queueFamilyIndex = queueFamilyIndex
    var newPool: VkCommandPool?
    guard vkCreateCommandPool(device, &poolInfo, nil, &newPool) == VK_SUCCESS, let newPool else {
      log("Vulkan3DManager: vkCreateCommandPool failed")
      return false
    }
    commandPool = newPool

    var allocInfo = VkCommandBufferAllocateInfo()
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
    allocInfo.commandPool = newPool
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY
    allocInfo.commandBufferCount = 1
    var newBuffer: VkCommandBuffer?
    guard vkAllocateCommandBuffers(device, &allocInfo, &newBuffer) == VK_SUCCESS else {
      log("Vulkan3DManager: vkAllocateCommandBuffers failed")
      return false
    }
    commandBuffer = newBuffer
    return true
  }

  func createSyncObjects() -> Bool {
    guard let device else { return false }
    var semaphoreInfo = VkSemaphoreCreateInfo()
    semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
    var fenceInfo = VkFenceCreateInfo()
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
    fenceInfo.flags = UInt32(VK_FENCE_CREATE_SIGNALED_BIT.rawValue)

    var imgSem: VkSemaphore?
    var renderSem: VkSemaphore?
    var fence: VkFence?
    guard vkCreateSemaphore(device, &semaphoreInfo, nil, &imgSem) == VK_SUCCESS,
      vkCreateSemaphore(device, &semaphoreInfo, nil, &renderSem) == VK_SUCCESS,
      vkCreateFence(device, &fenceInfo, nil, &fence) == VK_SUCCESS
    else {
      log("Vulkan3DManager: sync object creation failed")
      return false
    }
    imageAvailableSemaphore = imgSem
    renderFinishedSemaphore = renderSem
    inFlightFence = fence
    return true
  }

  func createDescriptorResources() -> Bool {
    guard let device else { return false }

    var binding = VkDescriptorSetLayoutBinding()
    binding.binding = 0
    binding.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    binding.descriptorCount = 1
    binding.stageFlags = UInt32(VK_SHADER_STAGE_FRAGMENT_BIT.rawValue)

    var newLayout: VkDescriptorSetLayout?
    let layoutResult = withUnsafePointer(to: binding) { bindingPtr -> VkResult in
      var createInfo = VkDescriptorSetLayoutCreateInfo()
      createInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
      createInfo.bindingCount = 1
      createInfo.pBindings = bindingPtr
      return vkCreateDescriptorSetLayout(device, &createInfo, nil, &newLayout)
    }
    guard layoutResult == VK_SUCCESS, let newLayout else {
      log("Vulkan3DManager: vkCreateDescriptorSetLayout failed")
      return false
    }
    descriptorSetLayout = newLayout

    // Generous fixed capacity (backdrop + a handful of level decals + the chest emblem) - matches
    // this project's "simplicity over dynamic sizing" precedent; bump if a level ever needs more
    // distinct sprite textures than this.
    let maxSets: UInt32 = 64
    var poolSize = VkDescriptorPoolSize(
      type: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, descriptorCount: maxSets)
    var newPool: VkDescriptorPool?
    let poolResult = withUnsafePointer(to: poolSize) { poolSizePtr -> VkResult in
      var createInfo = VkDescriptorPoolCreateInfo()
      createInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
      createInfo.maxSets = maxSets
      createInfo.poolSizeCount = 1
      createInfo.pPoolSizes = poolSizePtr
      return vkCreateDescriptorPool(device, &createInfo, nil, &newPool)
    }
    guard poolResult == VK_SUCCESS, let newPool else {
      log("Vulkan3DManager: vkCreateDescriptorPool failed")
      return false
    }
    descriptorPool = newPool

    var samplerInfo = VkSamplerCreateInfo()
    samplerInfo.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
    samplerInfo.magFilter = VK_FILTER_LINEAR
    samplerInfo.minFilter = VK_FILTER_LINEAR
    samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
    samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
    samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
    samplerInfo.borderColor = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
    var newSampler: VkSampler?
    guard vkCreateSampler(device, &samplerInfo, nil, &newSampler) == VK_SUCCESS else {
      log("Vulkan3DManager: vkCreateSampler failed")
      return false
    }
    sampler = newSampler
    return true
  }
}
