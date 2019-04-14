SwiftNNTrainier is a program for training neural networks using Apples' Metal Performance Shader library.  The program allows you to define a data source, create a network topology, and test and/or train the network using that data.

#### Latest Added Features
* Importing and exporting some models to/from MLModel files.  You can now use SwiftNNTrainer to create mlmodel files for use in other applications.

* Scaling of 3D View X axis

* Model parameter counting

* Labels are now stored as part of the document.  This allows labels to be loaded/saved from/to MLModel files

* Document file version is now 2 - so document files written by this version will not be able to be read by older versions.

## Installation Requirements
The program now requires the Swift protobuf framework.  This is used to read and write MLModel files.  A MacOS version of the framework is included in the project files, but will have to installed into an appropriate directory.  If you wish, download and build the latest version from [here](https://github.com/apple/swift-protobuf).

## Intro

![Image](Manual/NetworkTab.png)

The starting of a manual is available [here](Manual/Manual.md): 

Currently, only a single network path is allowed, unless you are running MacOS 10.15 or later - and as I have not upgraded to that beta, multi-path networks have not been tested.

Data can come from text files, binary files, or directories of images.  The format for parsing text and binary files can be specified.  A directory of example files with format specifiers for some more popular data sets (MNIST, CIFAR-10, etc.) is provided [here](Examples/Data Loaders).

Layer types allowed in the network include Convolutional, Fully Connected, Neuron (non-linearities), Pooling, Batch Normalization, Drop-Out, and SoftMax.  The data flow for the network is shown on a 3D graph, with the input and output data sizes for each layer represented geometrically.

Training parameters like batch size, number of epochs, and learning rates can be specified between each training set.  Testing can be done between epochs, with the error value from testing live-plotted as training continues.

As usual, this program is a work in progress.  Please inform me of any issues you find, or features you feel need to be added.

### Thanks To...
I'd like to thank the following open-source projects for providing some insight on how to do some of this:

* https://github.com/joshnewnham/Hands-On-Deep-Learning-with-Swift
* https://github.com/hollance/YOLO-CoreML-MPSNNGraph
* https://github.com/opedge/MPSCNNConvolutionTest

### Quick Start
A quick way to get started with the program is to load one of the provided data set reader documents, use the duplicate menu command to make a copy, then close the reader template (to leave it unmodified).  You can then change the location of the data source files to match your system (on the Data tab), create your network (on the Network tab), and start training (on the Training tab).  Don't forget to save your document after creating the network - training usually takes several attempts to find the proper hyper-parameters.

### Quickest Start
The following will get you started using SwiftNNTrainer
* Download the project
* Install the protobuf framework in a directory configured for frameworks
* Build the project
* Download the [MNIST data set](http://yann.lecun.com/exdb/mnist/)
* Run the SwiftNNTrainer program
* Open the Examples/Network Models/MNIST LeNet-1 document
* Change the four input files on the Data tab to point to where _you_ put the MNIST data (use the Browse buttons)
* Click "Load" in the lower-left of the Data tab. Wait for the load to finish
* Look at the network on the Network tab
* Go to the Training tab
* Click "Test". You should get about a 10% accuracy - random guess level
* Click "Train".  Watch the average error plot show the results as training progresses.  Wait for training to end.
* Click "Test" again.  This time, you will likely get in the upper 80% range.  Not bad for less than a minute of training!
* Click on the "View" button next to the Average Error Testing field.  Look at the input data and the label fields.  Use the arrow buttons and Sample field to move through the data set and see what digits your network gets right, and what it misses.
* Dismiss the View sheet
* Lower the Learning Rate by about a factor of 5-10
* Train again
* Test again

### The Simplest Network
The following steps will define the simplest network possible - a single neuron connected to two inputs.  The data is an 'OR' gate, with the output a 1 when either of the two inputs (which range randomly between 0 and 1) are above 0.5.  Since a single network can only linearly separate the data, and the function is three-quarters of the input space (imagine a square with the lower-left corner not filled in), a perfect training is not possible, but an 80% or better is.

* Open a new document
* Set the input dimensions to 2x1x1x1
* Set the output dimensions to 1x1x1x1
* Set the output type to classification
* Set the input source to 'Generated'.  With those input and output dimensions, the 'OR' problem data set will be created
* Load the data - 1000 training samples and 100 testing samples should be generated
* Go the the Network Tab.  The 3D View should show a 2 block input and 1 block output - we need to connect them
* Create a layer with the following parameters - Fully Connected, normal weights, 1 neuron, use bias term, update rule of standard SGD (most of these settings should be the defaults)
* Add the layer.  The network should now be valid.
* Use Mean-Squared-Error as the loss function
* Go to the Training Tab
* Change the batch size to 10
* Test - you should get about a 25% classification rate from random chance
* Set the number of epochs to 100
* Turn off 'test after every...'.  Training will be quick
* Click the 'Train' button
* Test again - you should now get a fairly high number for classification percentage, in the high eighties or even nineties.
