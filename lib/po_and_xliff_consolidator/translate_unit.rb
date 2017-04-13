require_relative 'logging'

module PoAndXliffConsolidator
  class TranslateUnit
    include Comparable
    include Logging

    attr_accessor :msgid
    attr_accessor :msgstr
    attr :msgid_downcase
    attr :msgid_downcase_singular
    attr :priority

    @@priorities = []

    def <=>(a_n_other)
      return -1 if priority < a_n_other.priority
      return 1 if priority > a_n_other.priority
      return -1 if msgid_downcase_singular < a_n_other.msgid_downcase_singular
      return 1 if msgid_downcase_singular > a_n_other.msgid_downcase_singular
      msgid_downcase <=> a_n_other.msgid_downcase
    end

    def initialize(msgid, msgstr)
      self.msgid = msgid
      self.msgstr = msgstr
    end

    def msgid=(msgid)
      @msgid = Transform.intelligent_chomp_string(msgid)
      @msgid_downcase = TranslateUnit::msgid_key(msgid)
      @msgid_downcase_singular = @msgid_downcase.chomp('s')
      set_priority
    end

    def set_priority
      @@priorities.each_with_index do |string, index|
        if msgid_downcase.include? string
          @priority = index
          break
        end
        @priority = @@priorities.count
      end
    end

    def msgstr=(msgstr)
      @msgstr = Transform.intelligent_chomp_string(msgstr)
    end

    def self.msgid_key(msgid)
      Transform::intelligent_chomp(msgid)[:str].downcase
    end

    def ==(other)
      self.class === other and msgid_downcase == other.msgid_downcase
    end

    alias eql? ==

    def hash
      msgid_downcase.hash
    end

    def inspect
      @msgid
    end

    def to_s
      msgid
    end
  end
end
