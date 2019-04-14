#Swift Neural Network Trainer Manual

The SwiftNNTrainier program is a standard MacOS Document application - with menus allowing loading, saving, duplicating, and other control of multiple windows, each being a separate instance of a document.  In this case a document contains the data definition, network layout, and training parameters.  As most of the menus and document controls are Mac OS document application standards, they will not be discussed at this time.  Instead, this manual will focus on the use of the three tabs on the main window, and the pop-up sheets.  It is these items that allow specification of the information needed to create and train a network


The main window is a tab-based control with three selections:  [Data](DataTab.md), [Network](NetworkTab.md), and [Training](TrainingTab.md).

The Data tab is used to define the input and output data sizes, the files or folders that contain the training and optionally the testing data sets, and to define the format of the data in those files.  You must load your data from this page as well, before training or testing it on the Training Tab.  For more information, go [here](DataTab.md).

The Network tab is used to define the topology of the network.  You configure and add layers to a process stack to convert the input data into the outputs.  The shape of the data is shown on a 3D image, which gives feedback as to where data sizing issues may occur in your network.  For more information, go [here](NetworkTab.md).

The Training tab is used to define the training parameters, such as batch size, number of epochs, and the learning rate.  Once these are defined you can test your network against the test data or start a training session.  Training sessions can be 'instrumented' with a testing phase (full or partial testing set used) every few epochs, with the resulting error value plotted in real time.  For more information, go [here](TrainingTab.md).

## Importing MLModel Files
It is possible to import an MLModel file into SwiftNNTrainer.  The model is read and converted into MPSCNN layers from MLModel layers.  As MLModel files do not have training or testing features, you will have to add update rules to the layers, define the training and testing data sources, etc.

To import an MLModel, use the File menu "Import MLModel..." command.  Select the MLModel file in the dialog that comes up.  A new document will open with the converted model.

## Exporting MLModel Files
The File menu now contains a submenu called "Export MLModel".  The submenu contains two items - "With Array Input..." and "With Image Input...".  Either command will activate a save dialog where you select the location and name of the MLModel file to be created.  The input type for the model will be set to either an MultiArray, or an Image, depending on which command you pick (the name of the input is just "input"), sized based on the input dimensions selected.  The layers of the current document will be converted and added to the model.  The output will be defined as either an MultiArray for regressors, or a Dictionary for classifiers (named "output").

The classifier output dictionary will use the string labels defined on the Data tab for keys, or an Int64 numeric value for each output channel if labels are not defined.  The dictionary values are the results of the network for each channel.  Classifiers also get a second output, called "label", which is the string or Int64 key from the dictionary that has the highest score.

## Import/Export Limitations
Only models, not pipelines can be imported or exported.
The only model types that can be imported are Neural Network Classifiers, Neural Network Regressors, and generic Neural Network models (which are loaded initially as a regressor).  Exporting will create a Neural Network Classifier or a Neural Network Regressor depending on the output type selected on the Data Tab.

The following layer types are currently supported for importing and exporting.  Items in parenthesis are terms used by MLModel, rather than MPSCNN:

* Convolutional
* Fully Connected (InnerProduct)
* Pooling
* Neuron (Activation)
* Softmax
* (Flatten) - ignored on import as not needed by MPS layers
* Normalization - although a limited subset