################################################################################
# Style file for markdownlint.
#
# https://github.com/markdownlint/markdownlint/blob/master/docs/configuration.md
#
# This file is referenced by the project `.mdlrc`.
################################################################################

#===============================================================================
# Start with all built-in rules.
# https://github.com/markdownlint/markdownlint/blob/master/docs/RULES.md
all

#===============================================================================
# Exclude the rules

# We strive to not restrict line lengths
# https://github.com/elastisys/ck8s-apps/blob/master/DEVELOPMENT.md#markdown
exclude_rule 'MD013'

# Needed since the github issues can't comply with this
# Fix when https://github.com/markdownlint/markdownlint/issues/368 is closed
exclude_rule 'MD041'
