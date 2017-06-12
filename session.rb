class Channel
  def initialize consumer
    @listeners = Set.new
    @mutex = Mutex.new
    @consumer = consumer
  end

  def listen q
    @mutex.synchronize do
      @listeners << q
      q << @consumer.state
    end
  end

  def unlisten q
    @listeners.delete q
  end

  def << cmd
    @mutex.synchronize do
      data = @consumer.consume cmd
      @listeners.each { |q| q << data }
    end
  end
end

class SessionManager
  def initialize klass
    @klass = klass
    @serial = 0
    @mutex = Mutex.new
    @channel = Channel.new
    @sessions = {}
  end

  def event sid, data
    @sessions[sid]&.event data
  end

  def run
    session, queue = nil
    @mutex.synchronize do
      @serial += 1
      sid = "#{@serial}-#{rand(0x10000).to_s(16)}"
      queue = Queue.new
      session = @klass.new
      @sessions[sid] = session
    end
    @channel.listen queue
    session.run sid, queue, @channel
  ensure
    @sessions.delete sid
    session.unlisten queue
  end
end
