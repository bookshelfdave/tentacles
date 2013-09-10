require 'rubygems'
require 'readline'
require 'net/ssh'
require 'highline/import'
require 'yaml'

config = YAML.load_file('config.yml')
puts config

@username = ask("Username: ")
@password = ask("sudo Password: ") { |q| q.echo = "x" }

def run(cmd, servers) 
  servers.each do |s|
    puts ">>> #{s}"
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
  line = Readline.readline('> ', true)
  return nil if line.nil?
  if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
    Readline::HISTORY.pop
  end
  line
end

currentcluster = config["default"]

while line = readline_with_hist_management
  if line =~ /^!/ then
    currentcluster = line[1,line.length].strip()
    puts currentcluster
  elsif line.strip() == "cluster" then
    puts currentcluster
    puts config[currentcluster]
  elsif line.strip() == "config" then
    config.keys.each do |k|
      puts "#{k}: #{config[k]}"
    end
  else
    run(line, config[currentcluster])
  end
end

