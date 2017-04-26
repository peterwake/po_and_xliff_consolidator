[![Build Status](https://travis-ci.org/peterwake/po_and_xliff_consolidator.svg?branch=master)](https://travis-ci.org/peterwake/po_and_xliff_consolidator)
[![Gem Version](https://badge.fury.io/rb/po_and_xliff_consolidator.svg)](https://badge.fury.io/rb/po_and_xliff_consolidator)


# Consolidate PO and Xliff Files

Used to manage translation files required by a web app using .po files and an iOS app using .xliff files, consolidating them into one set of files.

For our application, we are using FastGetText[https://github.com/grosser/fast_gettext] with Rails, and then Pootle with the Git FileSystem extension to do the translations.

## Neat Features

This gem will:
 * combine the .po and .xliff files ready for translation
 * eliminate duplicate phrases in both apps
 * deal with phrases ending in common endings like : ... or identical upper and lower case phrases
 * count the number of phrases and words where there is outstanding work
 * group phrases based on priority keywords to help the translators
 * extract back using the original .po and .xliff file structure, putting the result in a different directory
 * look out for phrases with variables inside them and warn if the token has accidentally been translated by the translator (like %{count} or %count% or %@)
 * skips phrases you don't want translated - sometimes Xcode extracts phrases automatically that you just don't want translating 
 * on extraction, can skip warning messages where you have previously identified the message is OK (e.g. where the translation is identical in both languages)
 
## Setup
 
 Add the following to your Gemfile:
 
 `gem 'po_and_xliff_consolidator'`

Then `bundle install`


## Translation Process

### File Management

I strongly recommend you create a new, *private* Git repository called say `myapp-i18n`. This makes sure you can keep track on what's changed, and revert if things go wrong.

It should have a folder structure

```
combine.rb
extract.rb
/combined
/web-app/need-translating
/web-app/translated
/xliff/need-translating
/xliff/translated
```


### Web App Export
 * in Rails, we are assuming you are using fastgettext, and your app is called 'myapp'
 * create a web app branch, say `translations-2017-01-16`
 * run `rake gettext:find`
 * this will create files called `myapp.po` in folders `/de` `/it` etc in `/config/locales`
 * copy files in myapp-web folder `/config/locales` into your new myapp-i18n repository `/web-app/need-translating/locales`
 * you can just dump everything in there, including .edit.po and .timestamp files, although these aren't used.

### iPad App Export
 * create an iPad app branch, say `translations-2017-01-16`
 * In the Project Navigator, go to the root of the app
 * Click on the 'Project'
 * Select Editor..Export for Localization
 * Save in `/xliff` with the name `need-translating`
 * It should say `need-translating` already exists - overwrite? Say Yes
 * Include existing translations
 * This will create files named e.g. `de.xliff` in this folder


### Consolidation
 First, commit `myapp-i18n` with Github
 
 Create a file like this in the root directory of your myapp-i18n repository:
 
 combine.rb
 ```ruby
 require 'po_and_xliff_consolidator'
 
 # Specify priority keywords - any phrases with these keywords in will be grouped together to help the translator
 PoAndXliffConsolidator::TranslateUnit.class_variable_set(:@@priorities, 
     ['review template','review','task','store','photo','document','deadline'])
 
 c = PoAndXliffConsolidator::Combine.new
 c.root_file_path = __dir__
 c.app_name = 'myapp' # whatever your .po files are called
 c.skip_strings=['','*', '$(PRODUCT_NAME)', 'PPT','PDF']
 c.skip_regexes = [/^\d+$/,/^\d+\.\d+$/,/^\d+\.\d+\.\d+$/] # 1, 1.1, 1.1.1
 # You can use the default logger or specify your own logger
 # You can set the logger level if you want, but start with this commented out!
 # c.logger.level = Logger::INFO
 
 # We use an array for Chinese, because the .po and .xliff files are named differently
 # .po first, .xliff second
 languages = [
     'de', 'es', ['zh_CN', 'zh-Hans']
 ]
 
 languages.each do |lang|
   c.process(lang)
 end
 ```
 

 
 * On command line, run this `combine` program
 * This will consolidate files into the `combined` folder with GNU friendly names `ar.po`, `de.po`, etc
 * Commit changes to Github

### Translation

 * Send the consolidated files out to be translated - we run a private Pootle server with pootle_fs_git installed, but I guess you could use Google Translation tools or something else.
 * Get the translations back! And paste them back into the `combined` folder
 * Check the translations! (don't pay for them until you've tried extracting)


### Extraction
 Sync `myapp-i18n` with Github
 
 Create a file like this in the root directory of your myapp-i18n repository:
 
extract.rb
```ruby
require 'po_and_xliff_consolidator'

c = PoAndXliffConsolidator::Extract.new
c.root_file_path = __dir__
c.app_name = 'myapp' # whatever your .po files are called
c.skip_strings=['','*', '$(PRODUCT_NAME)', 'PPT','PDF']
c.skip_regexes = [/^\d+$/,/^\d+\.\d+$/,/^\d+\.\d+\.\d+$/] # 1, 1.1, 1.1.1
#
# c.reset_identical_msgid_and_msgstr = true
#
# c.logger.level = Logger::WARN
# c.logger.formatter = proc do |severity, datetime, progname, msg|
#  "#{severity}: #{msg}\n"
# end
#
# messages_to_skip = YAML.load_file('messages_to_skip.yml')
# c.logger.skip(messages_to_skip)
#

languages = [
    'de', 'es', ['zh_CN', 'zh-Hans']
]

languages.each do |lang|
  c.process(lang)
end
#
# puts c.logger.messages.to_yaml
```
 
 * On command line under the `myapp-i18n` folder, run the `extract` program
 * Fix any glitches you can in the newly translated files, e.g. variable names %{count} etc
 * Check for any warnings and send these back to the translation company if necessary
 * This will extract files in the `combined` folder  to the `/xliff/translated` and `/web-app/need-translating/locales`
 * Check and commit changes to Github
 * If you have changed any of the 'combined' files, and you're using pootle, do a `pootle fs sync myapp` again
 
### Web App Import
 * Switch to master branch of myapp-web and make sure it is up to date
 * Switch to your Github branch again, say `translations-2017-01-16`
 * Merge master into the branch
 * copy files in myapp-web folder `/web-app/need-translating/locales` into `/config`
 
For example:
```sh
cd ~/..path_to../myapp-web
git checkout master
git pull
git checkout translations
git merge master
git push
cp -Rv ~/..path_to../myapp-i18n/web-app/translated/locales ~/..path_to../myapp-web/config
git status
git commit -m "Update translations"
git push
```
 
### iPad App Import
 * Make sure you are on the correct Github branch again, say `translations-2017-01-16`
 * In the Project Navigator, go to the root of the app 'MyApp Enterprise'
 * Click on the 'Project' MyApp Enterprise
 * Select Editor..Import Localizations
 * Pick in `/xliff/translated`
 * Repeat for each language
 
 Enjoy and good luck!


 
 
 
