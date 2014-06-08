FeedFace
========

FeedFace is an Objective-C framework for Mac OS X, that aids in interacting with other processes (e.g. to perform tasks such as reading and writing). Such interacting also includes the exposing and modifying of the Objective-C runtime.

Notes:
--
It is currently a work in progress, so there's a lot of functionality that still needs to be added. So it may not be particularly useful as it currently stands. It also should be noted that most development goes towards targeting x86_64 processes, while 32 bit processes come later; same with the focus being on the new Obj-C runtime, while old runtime will be worked on later.


Versions:
--
Versions currently imply the latest standalone builds. So these are builds which may not be compatible with the commits that follow. The main reason for this is when the runtime updates there may be incompatible changes. Ideally this should be detected an handled automatically so all versions can be handled in the same build and framework choose what's appropriate (or at the worst you specify the latest runtime build). But instead for the time being this will just be marked by tags, and from then on work is on the next awaiting tag.

The current tag versions and what their latest support runtime version is (or any other reasoning) can be seen below:

v1.0 -> objc4-532.x (some incompatible flag value changes in more recent versions), pre-Mavericks?


Installation:
--
Build the project and move the FeedFace.framework to your project or suggested framework installation directories (e.g. /Library/Frameworks or single user ~/Library/Frameworks).