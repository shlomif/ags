require 'pstore'
require 'stringio'
require 'socket'

class Stop < RuntimeError
  def initialize(s)
    super(s)
  end
end

class PStore
  def get(*k)
    if k.size == 1
      transaction(true) do
        self[k[0]]
      end
    else
      transaction(true) do
        k.map{|v|self[v]}
      end
    end
  end
end

class Hash
  def method_missing(s, *a)
    if key?(s)
      val_(self[s])
    elsif key?(t=s.to_s)
      val_(self[t])
    else
      super(s, *a)
    end
  end
  def val_(r)
    if r.class == Array && r.size == 1
      r[0]
    else
      r
    end
  end
end

class Handler
  def root_url
    if develop?
      'http://127.0.0.1:81'
    else
      'http://golf.shinh.org'
    end
  end

  def handle(req)
    @req = req
    @i = req.in
    @o = req.out
    @e = req.env
    @headered = nil

    #if @e['SERVER_NAME'] != 'golf.shinh.org'
    if false
      print "Status Code: 301 Moved Permanently\r\n"
      l = @e['REQUEST_URI']
      print "Location: #{root_url}#{l}\r\n"
      print "\r\n"
      return
    end

    begin
      handle_
    rescue
      if @orig_o
        puts end_buffering
      end

      if $!.class == Stop
        html_header if !@headered
        puts "Error:"
        puts $!
      else
        html_header if !@headered
        print "<p>#{$!}:</p><pre>#{$!.backtrace*"\n"}</pre>"
      end
    end

    @req.finish
  end

  def html_header(h={})
    @headered = true
    print "Content-Type: text/html; charset=UTF-8\r\n"
    h.each do |k, v|
      print "#{k}: #{v}\r\n"
    end
    print "\r\n"
  end
  def text_header(h={})
    @headered = true
    print "Content-Type: text/plain\r\n"
    h.each do |k, v|
      print "#{k}: #{v}\r\n"
    end
    print "\r\n"
  end
  def redirect(l)
    print "Status Code: 300 Found\r\n"
    print "Location: #{root_url}#{l}\r\n"
    print "\r\n"
  end

  def user_name
    @e['HTTP_COOKIE'] =~ /un=(.*)/
    $1 ? CGI.unescape($1) : ''
  end

  def err(e)
    raise Stop.new(e)
  end

  def store(d, q)
    db = PStore.new('db/' + d + '.db')
    db.transaction do
      q.each do |k, x|
        x = x[0] if x.class == Array && x.size == 1
        db[k] = x
      end
    end
  end

  def file_types
    ['rb','pl','py','php','scm','l','io','js','lua','tcl','xtal','kt','cy',
     'st', 'pro','for','bas',
     'pl6', 'erl', 'ijs', 'a+', 'mind',
     'c','cpp','d','ml','hs','adb','m','java','pas','f95','cs','n','cob','curry','lmn','max','reb',
     'awk','sed','sh','xgawk','m4','ps','r','vhdl','qcl',
     'bf','ws','bef', 'pef', 'ms', 'gs', 'unl', 'lazy', 'grass', 'lamb', 'wr', 'di',
     's','out','z8b','com','class','vi','grb',
     'groovy']
  end
  def file_langs
    ['Ruby','Perl','Python','PHP','Scheme',
     'Common LISP','Io','JavaScript','Lua','Tcl','Xtal','Kite','Cyan',
     'Smalltalk', 'Prolog','Forth','BASIC',
     'Perl6', 'Erlang', 'J', 'A+', 'Mind',
     'C','C++','D','OCaml','Haskell',
     'Ada','ObjC','Java','Pascal','Fortran','C#','Nemerle','COBOL','Curry','LMNtal','Maxima','REBOL',
     'AWK','sed','Bash','xgawk','m4','Postscript','R','VHDL','QCL',
     'Brainfuck','Whitespace','Befunge','Pefunge','Minus','GolfScript','Unlambda','Lazy-K','Grass','Universal Lambda','Whirl','D-compile-time',
     'gas','x86','z80','DOS','JVM','vi','goruby',
     'Groovy']
  end

  def ext2lang(e)
    file_langs[file_types.index(e)]
  end

  def get_db(d)
    PStore.new('db/' + d + '.db')
  end

  def develop?
    @e['REMOTE_ADDR'] == '127.0.0.1'
  end

  def escape_binary(s)
    s.gsub(/[\x00-\x09\x0b-\x1f\x7f-\xff]/){'<span class="gray">\x%02x</span>'%$&[0]}
    #s
  end

  def print(*a)
    @o.print(*a)
  end
  def puts(*a)
    @o.puts(*a)
  end
  def p(*a)
    a.each do |x|
      @o.puts(x.inspect)
    end
  end

  def tr(*a)
    r = '<tr>'
    a.each do |x|
      r += "<td>#{x}</td>"
    end
    r += '</tr>'
  end

  def start_buffering
    @orig_o = @o
    @o = StringIO.new
  end

  def end_buffering
    @o.rewind
    r = @o.read
    @o = @orig_o
    r
  end

  def query
    CGI::parse(@i.read)
  end

  def problem_db
    PStore.new('db/problem.db')
  end

  def a(h, t, n=nil)
    if n
      %Q(<a href="#{h}" name="#{n}">#{t}</a>)
    else
      %Q(<a href="#{h}">#{t}</a>)
    end
  end

  def tag(t, c)
    %Q(<#{t}>#{c}</#{t}>)
  end

  def problem_url(x)
    '/p.rb?' + x.tr(' ','+')
  end

  def lang_url(x)
    '/l.rb?' + x
  end

  def page
    q = @e['QUERY_STRING']
    err('no page') if !q
    [q.tr('+',' '), q]
  end

  def time_diff(dl)
    dls = "%02d" % (dl % 60)
    dlm = "%02d" % ((dl / 60) % 60)
    dlh = (dl / 60 / 60) % 24
    dld = (dl / 60 / 60 / 24)
    dld = dld > 0 ? "#{dld}day(s) and " : ""
    "#{dld}#{dlh}:#{dlm}:#{dls}"
  end

  def title(t)
    print %Q(<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>

<head>
 <meta http-equiv="CONTENT-TYPE" content="text/html; charset=UTF-8">
 <title>#{t}</title>
 <link rev="MADE" href="mailto:shinichiro.hamaji _at_ gmail.com">
 <link rel="INDEX" href=".">
 <link rel="stylesheet" type="text/css" href="/site.css">
</head>

<body>)
  end

  def foot
    print %Q(<p><a href="/">return top</a></p></body></html>)
  end

  def mircbot(msg)
    begin
      sock = TCPSocket.new('127.1.1.1',9999)
      sock.print(msg)
      sock.close
    rescue
    end
  end

  def lranking(ext, l, pn, del=nil, pm=0)
    ret = %Q(<table border="1"><tr><th>Rank</th><th>User</th><th>Size</th><th>Time</th><th>Date</th><th><a href="bas.html">Statistics</a></th>)
    if del
      ret += del[0]
    end
    ret += %Q(</tr>)
    l.each_with_index do |v, i|
      st = v[4]
      if st
        if st[1]
          st = [st[0], st[2], st[3]]
        else
          st = [st[0], '?', '?']
        end
      else
        st = ['?','?','?']
      end
      un = CGI.escapeHTML(v[0])
      if pm == 1
        un = %Q(<a href="reveal.rb?#{CGI.escape(pn)}/#{CGI.escape(v[0])}/#{v[3].to_i}&#{ext}">#{un != '' ? un : '_'}</a>)
      end
      date = v[3].strftime('%y/%m/%d %H:%M:%S')
      if v[5] == 1
        date = %Q(<em class="pm">#{date}</em>)
      end
      ret += %Q(<tr><td>#{i+1}</td><td>#{un}</td><td>#{v[1]}</td><td>#{"%.4f"%v[2]}</td><td>#{date}</td><td>#{st.map{|x|"#{x}B"}*' / '}</td>)
      if del
        del[1].call(v)
      end
      ret += %Q(</tr>)
    end
    ret + %Q(</table>)
  end

  def ranking(pn, del, pm)
    ret=''
    lr = {}
    ret += tag('h2', 'Ranking')
    ldb = PStore.new("db/#{pn}/_ranks.db")
    ldb.transaction(true) do
      file_types.zip(file_langs).each do |ext, lang|
        next if !ldb.root?(ext)
        ret += tag('h3', a(lang_url(ext),lang)+' '+a("##{lang}",'_',"#{lang}"))
        l = ldb[ext]
        next if l.empty?

        min = l.sort{|a,b|a[1]<=>b[1]}[0]
        lr[ext] = [min[1],min[3],min[0]]
        #lr[ext] = [l[0][1],l[0][0]]

        ret += lranking(ext, l, pn, del, pm)
      end
    end
    [ret, lr]
  end

end