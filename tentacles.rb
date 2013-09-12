require 'rubygems'
require 'readline'
require 'net/ssh'
require 'highline/import'
require 'yaml'
require 'colorize'

config = YAML.load_file('config.yml')

@username = ask("Username: ")
@password = ask("sudo Password: ") { |q| q.echo = "x" }
@currentcluster = config["default"]
@cwd = nil

def run(cmd, servers) 
  servers.each do |s|
    puts ">>> #{s}".red
    Net::SSH.start(s, @username, :forward_agent=>true) do |session|
      session.open_channel do |channel|
        channel.request_pty do |c, success|
          raise "could not request pty" unless success
          channel.exec cmd
          channel.on_data do |c_, data|
            ## not safe :-(
            if data =~ /\[sudo\]/ then
              channel.send_data(@password + "\n")
            else
              puts data
            end
          end
        end
      end
      session.loop
    end
  end
end

def readline_with_hist_management
  line = Readline.readline("#{@currentcluster}> ", true)
  return nil if line.nil?
  if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
    Readline::HISTORY.pop
  end
  line
end

begin
  Readline.emacs_editing_mode
rescue NotImplementedError
  libedit = true
end


while line = readline_with_hist_management
  if line =~ /^!/ then
    newcluster = line[1,line.length].strip()
    if config.has_key?(newcluster) then
      @currentcluster = newcluster
       puts @currentcluster
    else
      puts "Invalid cluster id"
    end
  elsif line =~ /^\// then
    cd = line[1,line.length].strip()
      puts "cd to [#{cd}]"
      @cwd = cd
  elsif line.strip() == "cluster" then
    puts @currentcluster.to_s.blue
    puts config[@currentcluster].to_s.blue
  elsif line.strip() == "config" then
    config.keys.each do |k|
      puts "#{k}: #{config[k]}".green
    end
  elsif line =~ /^@/ then
      c = line[line.index(":")+1,line.length]
      puts "Command = #{c}"
      s = line[1,line.index(":")-1]
      ## move this somewhere else
      if @cwd != nil then
        run("cd #{@cwd} && #{c}", [s])
      else
        run(c, [s])
      end
  else
    if @cwd != nil then
      run("cd #{@cwd} && #{line}", config[@currentcluster])
    else
      run(line, config[@currentcluster])
    end
  end
end

