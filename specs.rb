class Specs

  class << self
    def method_missing(func, *args, &block)
      bm = nil
      if args[0].is_a?(Symbol)   # If symbol, use that as bookmark
        bm = args.shift
      else   # Climb tree one level
        parent = FileTree.parent
        bm = parent.sub(/./, '') if parent =~ /^:\w+$/
      end

      bm = (bm || 'm').to_sym

      #       thing, opts = nil, thing if thing.is_a?(Hash)

      test, quote = args

      quote = test if args.size == 1 && test =~ /\n/   # If only 1 arg and it's multiline, it must be a quote

      if quote   # If there's a quote, we're jumping, not running
        quote = Line.value
        quote =~ /([\.\/].+):(\d+)/

        path, line = $1, $2
        path.sub! /^\.\//, Bookmarks["$#{bm}"]   # Fix relative paths

        View.open path
        View.to_line line.to_i
        return
      end

      clazz = func.to_s
      dir = 'models'   # Assume model


      dir = 'controllers' if clazz =~ /s$/   # If it ends with s, assume controller
      dir = 'helpers' if clazz =~ /_helpers$/

      # Try in unit/ dir first
      path = "spec/unit/#{dir}/#{clazz}_spec.rb"
      # Try just spec/ if not found
      path = "spec/#{dir}/#{clazz}_spec.rb" if ! File.exists?("#{Bookmarks["$#{bm}"]}#{path}")

      # If xiki, fix paths
      #       if bm == :x
      # Ol << "path: #{path.inspect}"
      #         path.sub! /.+\//, 'spec/'
      #       end

      if Keys.prefix_u   # If U prefix, jump to test
        View.open "#{Bookmarks["$#{bm}"]}#{path}"
        Keys.clear_prefix
        View.to_highest
        if test =~ /^#/
          Search.forward "^ *describe .+['\"]#{$el.regexp_quote(test)}['\"]"
        else
          Search.forward "^ *it ['\"]#{$el.regexp_quote(test)}['\"]"
        end
        Move.to_line_text_beginning
        return
      end

      txt = self.run_spec path, test, bm
      txt.sub! /^F\n\n1\)\n/, ''   # Remove 1st few lines
      txt.sub! /^\.+\n\nFinished in.+\n\n/, ''   # Remove 1st when passing
      txt.sub! /^\(irb\):.+/m, ''   # Remove everything after (irb)

      txt.gsub! /^#{Bookmarks["$#{bm}"]}/m, './'   # Shorten the paths

      txt.sub! /nil\n$/, ''
      # CodeTree.no_search_option +

      txt.gsub!(/.+\/gems\/rr-.+\n/, '')
      txt.gsub!(/.+\/gems\/rspec-.+\n/, '')

      txt.gsub(/^/, '| ')

    end
  end

  def self.line_of_test path, test, bm
    found = nil; number = 1
    IO.foreach(Bookmarks["$#{bm}/#{path}"]) do |line|
      if line =~ /^ *describe.+#{test}\b/
        break found = number
      end
      number += 1
    end
    found
  end

  def self.run_spec path, test, bm
    params = [path]

    if test =~ /^#/   # If starts with #, find line number
      found = self.line_of_test path, test, bm
      params << "-l" << (found ? "#{found}" : "0")
    elsif test.is_a?(String)
      params << "-e" << test
    end

    #     command = bm == :x ?
    #       command = "Spec::Runner::CommandLine.run(Spec::Runner::OptionParser.parse(#{params.inspect}, $out_bufr, $out_bufr))" :

    # Rails
    command = "require 'spec'; reload!; Spec::Runner::CommandLine.run(Spec::Runner::OptionParser.parse(#{params.inspect}, $out_bufr, $out_bufr))"

    # Assume merb if a merb file exists
    # Merb
    if File.exists?(Bookmarks["$#{bm}/public/merb.fcgi"])
      command = "Merb::Mailer.delivery_method=:test_send; Spec::Runner::CommandLine.run(Spec::Runner::OptionParser.parse(#{params.inspect}, $out_bufr, $out_bufr)); Merb::Mailer.delivery_method=nil"
    end

    RubyConsole[bm].run(command)
  end

  # Pastes in for the line in the clipboard:
  #   Spec.foo "bar"
  def self.enter_as_rspec
    # If U, add it in $t
    prefix_u = Keys.prefix_u :clear=>true
    if prefix_u
      u_orig = Location.new
      Clipboard.as_line

      View.open "$t"
      #       Location.save(:insert_orig)
      View.to_highest

      View.insert("\n", :dont_move=>true) unless Line.blank?   # Make room if line not blank
    end
    if Line.blank?   # Assume clipboard contains "it..." line
      snippet = Clipboard['=']
      path = snippet[/.+/]
      clazz = snippet[/(\w+)_spec\.rb/, 1]

      desc = snippet[/(".+")/, 1]
      #       is_test = clazz.nil?
      #       clazz ||= snippet[/(\w+)_test\.rb/, 1]

      #       desc = snippet[/(".+")/, 1] || snippet[/('.+')/, 1]

      # If no description, do enter_as_title
      if desc.nil?
        View.insert TextUtil.title_case(Clipboard.get(0))
      else

        bms = Projects.listing.map{|o| o[1]}
        bm_were_in = bms.find{|o| path[Bookmarks[o]]}

        # Add symbol for project if it's a specific one
        project = bm_were_in ? "#{bm_were_in.sub('$', ':')}, " : ""
        project = "" if project == ":pm, "   # :m is the default, so not required
        View.insert "Specs.#{clazz} #{project}#{desc}"
      end
    else

      desc = Line[/  it (".+")/, 1]

      # If no description, do enter_as_title
      return View.insert TextUtil.title_case(Clipboard.get(0)) if desc.nil?

      orig = View.cursor
      Search.backward "^ *[+-] "
      clazz = Line[/(\w+)_spec\.rb/, 1]

      View.cursor = orig
      Line.delete :leave_linebreak
      View.insert "Specs.#{clazz} #{desc}"
      Move.to_axis
    end
    if prefix_u
      # Add line after if before heading
      unless match =~ /\n$/   # If there wasn't a linebreak at the end of the match
        Line.next
        View.insert("\n", :dont_move=>true) if Line[/^\|/]
      end
      Move.to_axis

      u_orig.go
    end

  end

  def self.run_spec_in_place
    Keys.clear_prefix
    cursor = View.cursor
    Move.to_end

    Search.backward '^ *it '   # Go up to "it ..." line
    path = View.file.sub /.+\/spec\//, 'spec/'
    test = Line.value[/(["'])(.+)\1/, 2]   # "
    test.gsub! "'", "\\\\'"   # Escape single quotes

    bms = Projects.listing.map{|o| o[1]}
    file_path = View.file
    bm_were_in = bms.find{|o|
      bm = Bookmarks[o]
      bm.any? && file_path[bm]
    }

    bm_were_in = bm_were_in.sub(/./, '').to_sym

    txt = self.run_spec path, test, bm_were_in
    Search.forward '^  end$'
    Move.forward
    View.insert "#{txt.gsub(/^/, '  # ').gsub(/^  # $/, '  #')}"

    View.cursor = cursor
  end

  #   def self.insert_in_todo
  #   end

end
