class Javascript
  def self.run
    # Get block contents
    txt, left, right = View.txt_per_prefix #:prefix=>Keys.prefix

    if Keys.prefix_u
      funcs = <<-JS
        function p(s) {
          if(s == null)
            s = "[blank]";

          try {prepend_index++;}
          catch(e) { prepend_index = 0; }

          var d = document.createElement('div');
          document.body.appendChild(d);
          d.innerHTML = '<div style="top:'+(prepend_index*13)+'px; margin-left:5px; position:absolute; font-size:10px; z-index:1002; color:#000; filter: alpha(opacity=85); -moz-opacity: .85; opacity: .85; background-color:#999;">'+s+'</div>';

        }
      JS

      Firefox.run "#{funcs}\n#{txt.gsub('\\', '\\\\\\')}"
      return
    end

    txt << "
      function p(txt) {
        print(txt);
      }";

    result = self.run_internal txt
    # Insert result at end of block
    orig = Location.new
    View.cursor = right
    Line.to_left
    View.insert result.gsub(/^/, '  ')
    orig.go
  end

  def self.run_internal txt

    # Remove comments
    txt.gsub! %r'^ *// .+', ''
    txt.gsub! %r'  // .+', ''

    # Write to temp file
    File.open("/tmp/tmp.js", "w") { |f| f << txt }
    # Call js
    Console.run "js /tmp/tmp.js", :sync=>true
  end

  def self.launch
    line = Line.without_label
    result = self.run_internal line
    FileTree.insert_under result, :escape=>''
  end

  def self.enter_as_jquery
    clip = Clipboard.get(0)
    insert_this = clip =~ /^[a-z_.#]+$/ ? clip : ""

    if Keys.prefix_u?
      View.insert "$(\"#{insert_this}\")"
      Search.backward '"'
      return
    end

    View.insert "- (js): $(\"#{insert_this}\").blink()"
    Search.backward '"'

  end

end
