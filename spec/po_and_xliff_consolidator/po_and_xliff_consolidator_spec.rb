require './lib/po_and_xliff_consolidator'
require 'fileutils'
require 'tmpdir'

support_directory = File.join('spec','support')
PoAndXliffConsolidator::TranslateUnit.class_variable_set(:@@priorities,['form','photo'])

describe PoAndXliffConsolidator do
  include PoAndXliffConsolidator

  it 'has a VERSION' do
    expect(PoAndXliffConsolidator::VERSION).to match(/^\d+\.\d+\.\d+$/)
  end

  context 'Translation units' do
    context 'Creating' do
      it 'Should create a translate unit' do
        tu = PoAndXliffConsolidator::TranslateUnit.new('Today','')
        expect(tu.msgid).to eq 'Today'
      end
      context 'Trimming' do
        [':','...',': ','..','...','…',"\n"].each do |extra_text|
          it "Should trim `#{extra_text}`" do
            tu = PoAndXliffConsolidator::TranslateUnit.new('Today'+extra_text,'')
            expect(tu.msgid).to eq 'Today'
          end
        end
        it 'Should not trim a single full stop' do
          tu = PoAndXliffConsolidator::TranslateUnit.new('Today.','')
          expect(tu.msgid).to eq 'Today.'
        end
      end
    end

    context 'Checking if equal' do
      it 'Should compare in a case-insensitive way' do
        tu1 = PoAndXliffConsolidator::TranslateUnit.new('today','')
        tu2 = PoAndXliffConsolidator::TranslateUnit.new('Today','')
        expect(tu1).to eq tu2
      end
    end

    context 'Sorting' do
      it 'Should sort priority strings together, and keep plural forms together' do
        tus = []
        ['photo','dog','this form','cow','forms','cat','photos','look at this form','form'].each do |msgid|
          tus << PoAndXliffConsolidator::TranslateUnit.new(msgid,'')
        end
        tus.sort!
        expect(tus.map(&:msgid)).to eq(['form','forms','look at this form','this form','photo','photos','cat','cow','dog'])
      end
    end
  end

  context 'Transforming back' do

    arr = [
        ['Today','Heute'],
        ['comments','Kommentare'],
        ['No active forms!','Keine aktiven Formulare!']
    ]

    tus = []

    e = PoAndXliffConsolidator::Extract.new

    arr.each do |msgid, msgstr|
      tu = PoAndXliffConsolidator::TranslateUnit.new(msgid, msgstr)
      tus << tu

      it 'Should handle exact matches' do
        expect(e.match_with_ending(msgid,tu)).to eq msgstr
      end
      [':','...',': ',' : ','..','...','…',"\n",'!'].each do |extra_text|
        it "Should add back `#{extra_text}`" do
          expect(e.match_with_ending(msgid + extra_text,tu)).to eq msgstr + extra_text
        end
      end
    end


    it 'Should not make capitalised translations (for example German nouns) lower case' do
      expect(e.match_with_ending('comments',tus[1])).to eq 'Kommentare'
      expect(e.match_with_ending('No active forms!',tus[2])). to eq 'Keine aktiven Formulare!'
    end

  end

  context 'Combining' do
    it 'should override blank msgstr' do
      c = PoAndXliffConsolidator::Combine.new
      c.reset_stores
      c.add_translation_unit('Password','')
      c.add_translation_unit('Password','Contraseña')
      expect(c.translation_units.count).to eq 1
      expect(c.translation_units[0].msgstr).to eq 'Contraseña'
    end

    it 'should set default paths' do
      c = PoAndXliffConsolidator::Combine.new
      c.root_file_path = support_directory
      c.set_language_codes('de')
      c.app_name = 'sample'

      test_arr = [
          [c.path_templates[:need_translating][:po], 'spec/support/web-app/need-translating/locales/de/sample.po'],
          [c.path_templates[:need_translating][:xliff], 'spec/support/xliff/need-translating/de.xliff'],
          [c.path_templates[:combined], 'spec/support/combined/de.po'],
          [c.path_templates[:translated][:po], 'spec/support/web-app/translated/locales/de/sample.po'],
          [c.path_templates[:translated][:xliff], 'spec/support/xliff/translated/de.xliff']
      ]

      test_arr.each do |path_template, expected_result|
        expect(c.get_path(path_template)).to eq expected_result
      end

    end

    it 'should handle different po and xliff language codes' do
      c = PoAndXliffConsolidator::Combine.new
      c.root_file_path = support_directory
      c.set_language_codes(['ko','ko-KR'])
      c.app_name = 'sample'

      test_arr = [
          [c.path_templates[:need_translating][:po], 'spec/support/web-app/need-translating/locales/ko/sample.po'],
          [c.path_templates[:need_translating][:xliff], 'spec/support/xliff/need-translating/ko-KR.xliff'],
          [c.path_templates[:combined], 'spec/support/combined/ko.po'],
          [c.path_templates[:translated][:po], 'spec/support/web-app/translated/locales/ko/sample.po'],
          [c.path_templates[:translated][:xliff], 'spec/support/xliff/translated/ko-KR.xliff']
      ]

      test_arr.each do |path_template, expected_result|
        expect(c.get_path(path_template)).to eq expected_result
      end
    end

    it 'Should combine a po and xliff file' do
      Dir.mktmpdir do |tmpdir|
        c = PoAndXliffConsolidator::Combine.new
        c.root_file_path = support_directory
        c.set_language_codes('de')
        c.app_name = 'sample'
        c.skip_strings=['*', 'CloseReviewViewController', 'MyAppName']
        c.skip_regexes = [/^\d+\.\d+\.\d+$/]

        reference_combined_file_name = c.combined_file_name

        tmpdir = '/tmp'

        c.path_templates[:translated] = {
            po: [tmpdir,'%{app_name}.po'],
            xliff: [tmpdir,'%{language_code}.xliff']
        }
        c.path_templates[:combined] = [tmpdir, '%{language_code}.po']

        c.process('de')

        expect(File.exists?(c.combined_file_name)).to be_truthy
        expect(FileUtils.compare_file(c.combined_file_name, reference_combined_file_name)).to be_truthy

      end
    end
  end

  context 'Extracting' do

    it 'Should extract a po and xliff file' do
      Dir.mktmpdir do |tmpdir|
        c = PoAndXliffConsolidator::Extract.new
        c.root_file_path = support_directory
        c.set_language_codes('de')
        c.app_name = 'sample'
        c.skip_strings=['*', 'CloseReviewViewController', 'MyAppName']
        c.skip_regexes = [/^\d+\.\d+\.\d+$/]

        reference_combined_po_file_name = c.web_app_filename(:translated)
        reference_combined_xcode_file_name = c.xcode_file_name(:translated)

        tmpdir = '/tmp'

        c.path_templates[:translated] = {
            po: [tmpdir,'%{app_name}.po'],
            xliff: [tmpdir,'%{language_code}.xliff']
        }

        c.process('de')

        expect(File.exists?(c.web_app_filename(:translated))).to be_truthy
        expect(File.exists?(c.xcode_file_name(:translated))).to be_truthy

        expect(FileUtils.compare_file(c.web_app_filename(:translated), reference_combined_po_file_name)).to be_truthy
        expect(FileUtils.compare_file(c.xcode_file_name(:translated), reference_combined_xcode_file_name)).to be_truthy

      end
    end
  end

end