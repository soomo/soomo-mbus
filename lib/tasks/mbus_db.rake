namespace :mbus_db do

  desc "Drop the database."
  task :drop do
    if File.exist?(dbname)
      puts "Removing DB #{dbname}"
      FileUtils.rm(dbname)
      if File.exist?(dbname)
        puts "DB #{dbname} still exists!"
      else
        puts "DB #{dbname} has been removed."
      end
    else
      puts "DB #{dbname} does not exist!"
    end
  end

  desc "Create the database."
  task :create do
    puts "Creating DB #{dbname}"
    db = SQLite3::Database.new(dbname)
    if establish_db_connection
      puts "DB created; #{dbname}"
    else
      puts "ERROR: DB NOT created; #{dbname}"
    end
  end

  desc "Migrate the database."
  task :migrate do
    if establish_db_connection
      ActiveRecord::Migrator.migrate("db/migrate/")
    end
  end

  desc "Create a Grade(s), n="
  task :create_grade do
    count = ENV['n'] ||= '1'
    Mbus::Io.initialize('core', init_options)
    if establish_db_connection
      count.to_i.times do
        g = Grade.new
        g.student_id  = rand(1000)
        g.course_id   = rand(100)
        g.grade_value = 60 + rand(41)
        g.save!
        g.grade_value = 60 + rand(41)
        g.save!
        g.miscalculate
      end
    end
    Mbus::Io.shutdown
  end

end

def env
  ENV['e'] ||= 'development'
end

def dbname
  config = YAML::load(File.open('config/database.yml'))[env]
  config['database']
end

def db_config
  YAML::load(File.open('config/database.yml'))[env]
end

def establish_db_connection
  ActiveRecord::Base.establish_connection(db_config)
  if ActiveRecord::Base.connection && ActiveRecord::Base.connection.active?
    puts "DB connection established to '#{db_config['database']}' in env '#{env}'"
    true
  else
    puts "ERROR: DB connection NOT established to '#{db_config['database']}' in env '#{env}'"
    false
  end
end

