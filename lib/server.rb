require 'fileutils'

class Server

  #==========================================================================

  VERSION = "1.0.0"
  DEFAULT_LOGFILE = "/var/log/ruby-sample-daemon.log"
  DEFAULT_PIDFILE = "/var/run/ruby-sample-daemon.pid"

  def self.run!(options)
    Server.new(options).run!
  end

  #==========================================================================

  attr_reader :options, :quit

  def daemonize?
    options[:daemonize]
  end

  def logfile
    options[:logfile] || (daemonize? ? DEFAULT_LOGFILE : nil)
  end

  def pidfile
    options[:pidfile] || (daemonize? ? DEFAULT_PIDFILE : nil)
  end

  #--------------------------------------------------------------------------

  def initialize(options)
    @options = options || {}
  end

  #--------------------------------------------------------------------------

  def run!

    check_pid                  # ensure server is not already running

    if daemonize?
      daemonize
    elsif logfile
      redirect_output
    end

    write_pid
    trap_server_signals
    do_work

  end

  #--------------------------------------------------------------------------

  def do_work
    while !quit
      # YOUR LONG RUNNING PROCESS GOES HERE
      info "Doing some work"
      sleep 2
    end
    info "Finished"
  end

  #--------------------------------------------------------------------------

  def info(msg)
    puts "[#{Process.pid}] [#{Time.now}] #{msg}"
  end

  #==========================================================================
  # DAEMONIZING, PID MANAGEMENT, and OUTPUT REDIRECTION
  #==========================================================================

  def daemonize
    exit if fork
    Process.setsid
    exit if fork
    Dir.chdir "/"
    redirect_output
  end

  def redirect_output
    if logfile
      output = File.expand_path(logfile)
      FileUtils.mkdir_p(File.dirname(output), :mode => 0755)
      FileUtils.touch output
      File.chmod(0644, output)
      $stderr.reopen(output, 'a')
      $stdout.reopen($stderr)
      $stdout.sync = $stderr.sync = true
    else
      $stderr.reopen('/dev/null', 'a')
      $stdout.reopen($stderr)
    end
  end

  def write_pid
    if pidfile
      begin
        File.open(pidfile, ::File::CREAT | ::File::EXCL | ::File::WRONLY){|f| f.write("#{Process.pid}") }
        at_exit { File.delete(pidfile) if File.exists?(pidfile) }
      rescue Errno::EEXIST
        check_pid
        retry
      end
    end
  end

  def check_pid
    if pidfile
      case pid_status(pidfile)
      when :running, :not_owned
        puts "A server is already running. Check #{pidfile}"
        exit(1)
      when :dead
        File.delete(pidfile)
      end
    end
  end

  def pid_status(pidfile)
    return :exited unless File.exists?(pidfile)
    pid = ::File.read(pidfile).to_i
    return :dead if pid == 0
    Process.kill(0, pid)
    :running
  rescue Errno::ESRCH
    :dead
  rescue Errno::EPERM
    :not_owned
  end

  #==========================================================================
  # SIGNAL HANDLING
  #==========================================================================

  def trap_server_signals

    trap(:QUIT) do   # graceful shutdown
      @quit = true
    end

    # you might want to trap other signals as well

  end

  #==========================================================================

end
