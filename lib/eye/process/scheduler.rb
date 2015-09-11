module Eye::Process::Scheduler

  # ex: schedule :update_config, config, "reason: update_config"
  def schedule(command, *args, &block)
    if scheduler.alive?
      if scheduler_freeze?
        warn ":#{command} ignoring to schedule, because scheduler is freeze"
        return
      end

      if command && !self.respond_to?(command, true)
        warn ":#{command} scheduling is unsupported"
        return
      end

      reason = if args.present? && args[-1].kind_of?(Eye::Reason)
        args.pop
      end

      info "schedule :#{command || 'block'} #{reason ? "(reason: #{reason})" : nil}"

      if reason.class == Eye::Reason
        # for auto reasons
        # skip already running commands and all in chain
        scheduler.add_wo_dups_current(:scheduled_action, command, {:args => args, :reason => reason}, &block)
      else
        # for manual, or without reason
        # skip only for last in chain
        scheduler.add_wo_dups(:scheduled_action, command, {:args => args, :reason => reason}, &block)
      end
    end
  end

  def schedule_in(interval, command, *args, &block)
    debug { "schedule_in #{interval} :#{command} #{args}" }
    after(interval.to_f) do
      debug { "scheduled_in #{interval} :#{command} #{args}" }
      schedule(command, *args, &block)
    end
  end

  def scheduled_action(command, h = {}, &block)
    reason = h.delete(:reason)
    info "=> #{command || 'block'} #{h[:args].present? ? "#{h[:args]*',' }" : nil} #{reason ? "(reason: #{reason})" : nil}"

    @current_scheduled_command = command
    @last_scheduled_command = command
    @last_scheduled_reason = reason
    @last_scheduled_at = Time.now

    if command
      send(command, *h[:args], &block)
    else
      current_actor.instance_exec(&block) if block
    end
    @current_scheduled_command = nil
    info "<= #{command}"

    schedule_history.push(command, reason, @last_scheduled_at.to_i)

    if parent = self.try(:parent)
      parent.schedule_history.push("#{command}_child", reason, @last_scheduled_at.to_i)
    end
  end

  def scheduler_actions_list
    scheduler.list.map{|c| c[:args].first rescue nil }.compact
  end

  def scheduler_clear_pending_list
    scheduler.clear_pending_list
  end

  def self.included(base)
    base.finalizer :remove_scheduler
  end

  attr_accessor :current_scheduled_command
  attr_accessor :last_scheduled_command, :last_scheduled_reason, :last_scheduled_at

  def schedule_history
    @schedule_history ||= Eye::Process::StatesHistory.new(50)
  end

  def scheduler_freeze
    @scheduler_freeze = true
  end

  def scheduler_unfreeze
    @scheduler_freeze = nil
  end

  def scheduler_freeze?
    @scheduler_freeze
  end

private

  def remove_scheduler
    @scheduler.terminate if @scheduler && @scheduler.alive?
  end

  def scheduler
    @scheduler ||= Eye::Utils::CelluloidChain.new(current_actor)
  end

end
