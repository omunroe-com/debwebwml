Building the website with GitLab CI
===================================

On every commit, the website will be built. By default, only the
following parts will be built:

- The english website (always).
- If any files were touched under a translation directory, that
  translation.

The built files will be made available as artifacts. These can be
browsed through the GitLab webinterface for basic review and validation
of any made changes. Note, however, that content negotiation does not
work on GitLab, and that internal links will be broken (because they
miss the `$language.html` suffix). This is expected.

The build can be fine-tuned by setting the list of forced translations.
This list can be set in two ways:

1. Add a line starting with `forced translations:` to the commit
   message, followed by the list;
2. Set the environment variable `WEBWML_FORCED_TRANSLATIONS` to the
   list of translations wanted. This can be done by going to the "CI/CD"
   option in the left-hand-side menu of GitLab, then choosing
   "Pipelines", and "Run Pipeline". There, fill out the name of the
   variable in "Input variable key" and its value in "Input variable
   value". You must be logged in and have access to the repository to be
   able to do so (but you may fork the repository, if you prefer).

If the list of translations is set to 'all', then all translations will
be built. If the list of translations is set to a space-separated list
of languages, then any language in that list will be built.

To skip GitLab CI altogether, make sure that either `[skip ci]` or `[ci
skip]` occurs in the commit message.

The CI jobs use a docker image that is stored in the GitLab container
registry. The Dockerfile for this image is stored [in this
repository](docker-image/Dockerfile)
