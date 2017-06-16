class DelayedJobNeverRanCheck < OkComputer::Check
  attr_reader :threshold

  def initialize(threshold)
    @threshold = threshold
  end

  def check
    never_ran = Delayed::Job.where('run_at <= ?', 5.minutes.ago).count

    if never_ran.zero?
      mark_message 'All previous jobs have completed'
    elsif never_ran <= threshold
      mark_message "#{never_ran} jobs still waiting to be executed (within threshold=#{threshold})"
    else
      mark_failure
      mark_message "#{never_ran} jobs stil waiting to be executed (over threshold=#{threshold})"
    end
  end
end

# Mount at /health_checks
OkComputer.mount_at = 'health_checks'

# Register delayed_job backed up test
dj_max = OpenProject::Configuration.health_checks_jobs_queue_count_threshold
OkComputer::Registry.register "delayed_jobs_backed_up",
                              OkComputer::DelayedJobBackedUpCheck.new(0, dj_max)

dj_never_ran_max = OpenProject::Configuration.health_checks_jobs_never_ran_count_threshold
OkComputer::Registry.register "delayed_jobs_never_ran",
                              DelayedJobNeverRanCheck.new(dj_never_ran_max)

# Make dj backed up optional due to bursts
OkComputer.make_optional %w(delayed_jobs_backed_up)

# Check if authentication required
authentication_password = OpenProject::Configuration.health_checks_authentication_password
if authentication_password.present?
  OkComputer.require_authentication('health_checks', authentication_password)
end
