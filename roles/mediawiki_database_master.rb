name "mediawiki_database_master"
description "database master for the mediawiki application."
run_list(
  "recipe[mysql::client]",
  "recipe[application]",
  "recipe[mediawiki]"
)
