require 'timeout'

class Channel
  attr_reader :id
  @@mutex = Mutex.new
  @@channels = {}
  def initialize
    @@mutex.synchronize do
      @id = rand(0xffffffff).to_s(32)
      @@channels[@id] = self
    end
    @queue = Queue.new
  end

  def closed?
    @queue.closed?
  end

  def close
    @@mutex.synchronize do
      @@channels.delete @id
    end
    @queue.close
  end

  def trigger cmd
    @queue << cmd
  end

  def deq timeout: 1
    return @queue.deq unless timeout
    Timeout.timeout(timeout) { @queue.deq } rescue nil
  end

  def path
    "/trigger/#{id}"
  end

  def self.trigger id, cmd
    @@mutex.synchronize do
      @@channels[id]&.trigger cmd
    end
  end
end

get '/trigger/:id' do
  Channel.trigger params[:id], params
end

post '/trigger/:id' do
  Channel.trigger params[:id], params
end
