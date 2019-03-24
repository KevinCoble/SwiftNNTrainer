#Additional Data
Some layer types require additional data for their configuration.  An example would be the drop-out rate for a Drop-Out layer.

The default value is set to a normal 'good' setting for these parameters, but you should check and/or set these values for your network.  The 'Additional Data' button on the Network Tab will be enabled for all layer types that have additional data settings.  Clicking the button will activate a dialog sheet that allows you to view and set these values.

The following table shows the additional data that can be set on each layer type


| Layer Type | Additional Data Item | Default Value |
| --- | --- | --- |
| Binary Convolution | Scaling Factor | 1 |
|  | Type (weight, xnor, and) | Binary Weight |
|  | Use Beta Scaling | false |
| Dilated Max Pooling | Dilation X | 1 |
|  | Dilation Y | 1 |
| Binary Fully Connected | Scaling Factor | 1 |
|  | Type (weight, xnor, and) | Binary Weight |
|  | Use Beta Scaling | false |
| ELU Neuron | ELU Scale Factor | 0.0 |
| Hard Sigmoid Neuron| Slope | 1.0 |
|  | Intercept | 0.0 |
| Linear Neuron| Slope | 1.0 |
|  | Intercept | 0.0 |
| PReLU Neuron | Channel Parameter 1 | 0.0 |
|  | Channel Parameter 2 | 0.0 |
|  | Channel Parameter 3 | 0.0 |
|  | Channel Parameter 4 | 0.0 |
|  | Channel Parameter 5 | 0.0 |
|  | Channel Parameter 6 | 0.0 |
|  | Channel Parameter 7 | 0.0 |
|  | Channel Parameter 8 | 0.0 |
|  | Channel Parameter 9 | 0.0 |
|  | Channel Parameter 10 | 0.0 |
|  | Channel Parameter 11 | 0.0 |
|  | Channel Parameter 12 | 0.0 |
| ReLUN Neuron | Slope | 1.0 |
|  | Clamp | 1.0 |
| ReLU Neuron | Leaky Slope | 0.0 |
| Soft Plus Neuron | Scale | 1.0 |
|  | Power | 1.0 |
| TanH Neuron | Scale | 1.0 |
|  | Multiplier | 1.0 |
| Cross Channel Normalization | Kernel Size | 1 |
| Local Contrast Normalization | Kernel Width | 1 |
|  | Kernel Height | 1 |
|  | P0 | 1.0 |
|  | PM | 1.0 |
|  | PS | 1.0 |
| Spatial Normalization | Kernel Width | 1 |
|  | Kernel Height | 1 |
| BiLinear Upsampling | Scale Factor X | 1.0 |
|  | Scale Factor Y | 1.0 |
| Nearest Upsampling | Scale Factor X | 1.0 |
|  | Scale Factor Y | 1.0 |
|  | Align Corners | true |
| Dropout | Keep Probability | 0.1 |
|  | Random Seed | &lt;random&gt; |
|  | Stride X | 1 |
|  | Stride Y | 1 |
|  | Stride Depth | 1 |
