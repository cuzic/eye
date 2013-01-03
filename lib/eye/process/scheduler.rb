module Eye::Process::Scheduler

  def schedule(command, *args, &block)
    info "schedule :#{command}"
    scheduler.add_no_dup(:scheduled_action, command, *args, &block)
  end

  def scheduled_action(command, *args, &block)
    info "=> #{command} #{args}"
    send(command, *args, &block)
    info "<= #{command}"
  end

  def finalize
    remove_scheduler
  end

  #finalize :remove_scheduler

private

  def remove_scheduler
    @scheduler.terminate if @scheduler && @scheduler.alive?
  end

  def scheduler
    @scheduler ||= Celluloid::Chain.new(current_actor)
  end

end