FeedFace
========

FeedFace is an Objective-C framework for Mac OS X, that aids in interacting with other processes (e.g. to perform tasks such as reading and writing). Such interacting also includes the exposing and modifying of the Objective-C runtime.

Notes:
--
It is currently a work in progress, so there's a lot of functionality that still needs to be added. So it may not be particularly useful as it currently stands. It also should be noted that most development goes towards targeting x86_64 processes, while 32 bit processes come later; same with the focus being on the new Obj-C runtime, while old runtime will be worked on later.

I'm taking a rapid prototyping approach with how I'm developing it, so expect chunks of code to be removed/changed from time to time (this can introduce bugs, so expect them; because of the nature of the project you should expect bugs anyway) and for certain features to go untested.

Installation:
--
Build the project and move the FeedFace.framework to your project or suggested framework installation directories (e.g. /Library/Frameworks or single user ~/Library/Frameworks).