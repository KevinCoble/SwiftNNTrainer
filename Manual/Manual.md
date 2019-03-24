#Swift Neural Network Trainer Manual

The SwiftNNTrainier program is a standard MacOS Document application - with menus allowing loading, saving, duplicating, and other control of multiple windows, each being a separate instance of a document.  In this case a document contains the data definition, network layout, and training parameters.  As the menus and document controls are standard, they will not be discussed at this time.  Instead, this manual will focus on the use of the three tabs on the main window, and the pop-up sheets.  It is these items that allow specification of the information needed to create and train a network


The main window is a tab-based control with three selections:  [Data](DataTab.md), [Network](NetworkTab.md), and [Training](TrainingTab.md).

The Data tab is used to define the input and output data sizes, the files or folders that contain the training and optionally the testing data sets, and to define the format of the data in those files.  You must load your data from this page as well, before training or testing it on the Training Tab.  For more information, go [here](DataTab.md).

The Network tab is used to define the topology of the network.  You configure and add layers to a process stack to convert the input data into the outputs.  The shape of the data is shown on a 3D image, which gives feedback as to where data sizing issues may occur in your network.  For more information, go [here](NetworkTab.md).

The Training tab is used to define the training parameters, such as batch size, number of epochs, and the learning rate.  Once these are defined you can test your network against the test data or start a training session.  Training sessions can be 'instrumented' with a testing phase (full or partial testing set used) every few epochs, with the resulting error value plotted in real time.  For more information, go [here](TrainingTab.md).