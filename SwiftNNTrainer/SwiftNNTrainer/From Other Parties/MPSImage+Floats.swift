//  From https://github.com/hollance/YOLO-CoreML-MPSNNGraph

import MetalPerformanceShaders

extension MPSImage {
  /**
    We receive the predicted output as an MPSImage. We need to convert this
    to an array of Floats that we can use from Swift.

    Because Metal is a graphics API, MPSImage stores the data in MTLTexture 
    objects. Each pixel from the texture stores 4 channels: R contains the 
    first channel, G is the second channel, B is the third, A is the fourth. 

    In addition, these individual R,G,B,A pixel components can be stored as 
    `.float16`, in which case we also have to convert the data type.

    ---WARNING---

    If there are > 4 channels in the MPSImage, then the channels are organized
    in the output as follows:

        [ 1,2,3,4,1,2,3,4,...,1,2,3,4,5,6,7,8,5,6,7,8,...,5,6,7,8 ]
      
    and not as you'd expect:

        [ 1,2,3,4,5,6,7,8,...,1,2,3,4,5,6,7,8,...,1,2,3,4,5,6,7,8 ]

    First are channels 1 - 4 for the entire image, followed by channels 5 - 8
    for the entire image, and so on. That happens because we copy the data out
    of the texture by slice, and we can't interleave slices.

    If the number of channels is not a multiple of 4, then the output will
    have padding bytes in it:

        [ 1,2,3,4,1,2,3,4,...,1,2,3,4,5,6,-,-,5,6,-,-,...,5,6,-,- ]

    The size of the array is therefore always a multiple of 4! So if you have
    a classifier for 10 classes, the output vector is 12 elements and the last
    two elements are zero.

    The only case where you get the kind of array you'd actually expect is
    when the number of channels is 1, 2, or 4 (i.e. there is only one slice):
    
        [ 1,1,1,...,1 ] or [ 1,2,1,2,1,2,...,1,2 ] or [ 1,2,3,4,...,1,2,3,4 ]
  */
  @nonobjc public func toFloatArray() -> [Float] {
    switch pixelFormat {
      case .r16Float, .rg16Float, .rgba16Float: return fromFloat16()
      case .r32Float, .rg32Float, .rgba32Float: return fromFloat32()
      default: fatalError("Pixel format \(pixelFormat) not supported")
    }
  }

  private func fromFloat16() -> [Float] {
    var outputFloat16 = convert(initial: Float16(0))
    return float16to32(&outputFloat16, count: outputFloat16.count)
  }

  private func fromFloat32() -> [Float] {
    return convert(initial: Float(0))
  }

  private func convert<T>(initial: T) -> [T] {
    let numSlices = (featureChannels + 3)/4

    // If the number of channels is not a multiple of 4, we may need to add 
    // padding. For 1 and 2 channels we don't need padding.
    let channelsPlusPadding = (featureChannels < 3) ? featureChannels : numSlices * 4

    // Find how many elements we need to copy over from each pixel in a slice.
    // For 1 channel it's just 1 element (R); for 2 channels it is 2 elements 
    // (R+G), and for any other number of channels it is 4 elements (RGBA).
    let numComponents = (featureChannels < 3) ? featureChannels : 4

    // Allocate the memory for the array. If batching is used, we need to copy
    // numSlices slices for each image in the batch.
    let count = width * height * channelsPlusPadding * numberOfImages
    var output = [T](repeating: initial, count: count)

    let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                           size: MTLSize(width: width, height: height, depth: 1))

    for i in 0..<numSlices*numberOfImages {
      texture.getBytes(&(output[width * height * numComponents * i]),
                       bytesPerRow: width * numComponents * MemoryLayout<T>.stride,
                       bytesPerImage: 0,
                       from: region,
                       mipmapLevel: 0,
                       slice: i)
    }
    return output
  }
}
