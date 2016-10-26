# Spin the Records

Electronic dance music enjoys great reputation today. However, it is not suitable for simply playing one track after the other, as contemporary media players would do. A new world of sound is entered if tracks are combined in disk-jockey style. This thesis demonstrates how to automatically synthesize an uninterrupted stream of music using disk-jockey techniques. The approach raises a search problem, that is tackled by employing model checking methods. A program capable of synthesizing all legitimate track combinations is designed whereas a temporal logical formula specifies what desirable qualities a combination shall have. The model checking tool [SPIN](https://www.spinroot.com) is then used to extract a sequence of tracks that meets the listeners’ requirements.

## Source

`model_sectionsteps.pml`

The performance optimized default model for use by the autoDJ app, as proposed in the thesis. One timeunit equals one track section.

`model_barsteps.pml`

The optional bar sized timesteps model for use by the autoDJ app (only for doing spin runs and showing results, mix generation is not supported).

## How to use

Models can be model checked as follows:

1. Install the model checking tool [SPIN](https://www.spinroot.com).

2. Copy the model (we will use `model_sectionsteps.pml` in the following) you want to verify to your local file system; result files will be generated.

3. To generate the pan code run:

  `$ spin -a model_sectionsteps.pml`
  
  To compile pan:

  `$ cc -o pan pan.c`
  
  To perform the verification:

  `$ ./pan -a`
  
4. If an error was found (i.e. a mix), we can translate the counterexample path to a human readable version:

  `$ spin -t model_sectionsteps.pml`
  
The console output will represent the synthesized mix.

## License

Copyright 2013 Jonas Langhabel. See [License][1] for details.

[1]: https://github.com/langhabel/spin-the-records/LICENSE
