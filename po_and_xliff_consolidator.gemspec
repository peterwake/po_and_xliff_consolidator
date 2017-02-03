name = 'po_and_xliff_consolidator'
require "./lib/#{name}/version"

Gem::Specification.new name, PoAndXliffConsolidator::VERSION do |s|
  s.summary = 'Consolidation of PO and XLIFF files into one PO file per language'
  s.authors = ['Peter Wake']
  s.email = ['firstname underscore surname at hotmail _dot_ com']
  s.homepage = "https://github.com/peterwake/#{name}"
  s.files = Dir['{lib/**/*.rb,README.md,CHANGELOG.md}']
  s.licenses = ['MIT', 'Ruby']
  s.required_ruby_version = '>= 2.1.0'

  s.add_runtime_dependency 'nokogiri', '~> 1.0'
  s.add_runtime_dependency 'words_counted', '~> 1.0'

  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rspec', '~> 2.0'
  s.add_development_dependency 'bump', '~> 0'
  s.add_development_dependency 'wwtd', '~> 1.0'
end