# Notes from the distutils-sig discussion

The conversation begins [here](https://mail.python.org/pipermail/distutils-sig/2016-January/027997.html).

- In the policy, where we list all of the permitted libraries, are these
  supposed to be the filenames of the permitted dependencies, or the SONAMEs
  of the permitted libraries. Should specify.


## Selected Responses

Some people take the position that the policy is too strict and does not allow
a sufficient number (and diversity of) system libraries to be linked against.

For example, M.-A. Lemburg wrote:

    It doesn't address needs of others that e.g. use Qt or GTK as basis for GUIs,
    people using OpenSSL for networking, people using ImageMagick for processing
    images, or type libs for type setting, or sound libs for doing sound
    processing, codec libs for video processing, etc.

    The idea to include the needed share libs in the wheel
    goes completely against the idea of relying on a system
    vendor to provide updates and security fixes. In some cases,
    this may be reasonable, but as design approach, it's
    not a good idea.

This response from Nathaniel is particularly well stated (maybe should be
adapted to put into the PEP):

    Is manylinux1 the perfect panacea for every package? Probably not. In
    particular it's great for popular cross platform packages, because it works
    now and means they can basically reuse the work that they're already doing
    to make static windows and OSX wheels; it's less optimal for smaller
    Linux-specific packages that might prefer to take more than of Linux's
    unique package management functionality and only care about targeting
    one or two distros.


Donald Stufft was concerrened in the opposite direction, and wondered if the
policy could be made even more strict:

    I guess my underlying question is, if we’re considering static linking
    (or shipping the .so dll style) to be good enough for everything not on
    this list, why are these specific packages on the list? Why are we not
    selecting the absolute bare minimum packages that you *cannot* reasonably
    static link or ship the .so?

Matthias Klose was concerned that we weren't providing support for other
archectures:

    so this is x86_64-linux-gnu. Any other architectures?

Later, he asked:

    Any reason to not list libz?

    so how are people supposed to build these wheels?  will you provide a
    development distribution, or do you "trust" people building such wheels?


Nathaniel wrote:

    The rule is basically: "if your wheel
    works when given access to CentOS 5's versions of the following
    packages: ..., then your wheel is manylinux1 compatible". Any method
    for achieving that is fair game :-).




From Nick :

    The PEP should also be explicit that this does reintroduce the
    bundling problem that distro unbundling policies were designed to
    address, but:

    1. In these days of automated continuous intregration & deployment
       pipelines, publishing new versions and updating dependencies is easier
       than it was when those policies were defined
    2. Folks remain free to use "--no-binary" if they want to force local
       builds rather than using pre-built wheel files
    3. The popularity of container based deployment and "immutable
       infrastructure" models involve substantial bundling at the application
       layer anyway
    4. This PEP doesn't rule out the idea of offering more targeted
       binaries for particular Linux distributions
