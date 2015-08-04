require 'mysql2'

module MysqlUsers
  class User
    attr_reader :db_client
    attr_reader :e_username
    attr_reader :e_scope

    def initialize(db_client, options={})
      @db_client = db_client
      @e_username = escape(options.fetch(:username))
      @e_scope = escape(options.fetch(:scope))
      p = options[:password]
      @e_password = p ? escape(p) : nil
      @raw_username = options[:username]
      @raw_scope = options[:scope]
    end

    def exists?
      query = "SELECT User, Scope FROM mysql.user WHERE "\
        "User='#{e_username}' AND Scope='#{e_scope}'"
      result = db_client.query(query)
      result.count != 0
    end

    def create_idempotently
      return if exists?
      create
    end

    def drop
      sql = "DROP USER '#{e_username}'@'#{e_scope}'"
      db_client.query(sql)
    end

    # TODO should this be its own class?
    def grant(options)
      db = backtick_or_star(options[:database])
      table = backtick_or_star(options[:table])
      grants = options.fetch(:grants)
      verify_grants_sanitized(grants)

      sql = "GRANT #{grants.join(',')}"
      sql += " ON #{db}.#{table}"
      sql += " TO '#{e_username}'@'#{e_scope}'"

      db_client.query(sql)
    end

    private

    def verify_grants_sanitized(grants)
      unless grants.all?{ |grant| /^[a-zA-Z ]+$/.match(grant) }
        raise "grants should match [a-zA-Z ]. Refusing to give grants"
      end
      if grants.empty?
        raise 'provided list of grants must be non-empty'
      end
    end

    def backtick_or_star(name)
      return '*' unless name
      backtick_error = 'refusing to give grants on an entity '\
        'whose name contains backticks'
      raise backtick_error if /`/.match(name)
      "`#{escape(name)}`"
    end

    def has_password?
      !@e_password.nil?
    end

    def create
      sql = "CREATE USER '#{e_username}'@'#{e_scope}'"
      sql += " IDENTIFIED BY '#{@e_password}'" if has_password?

      db_client.query(sql)
    end

    def escape(string)
      Mysql2::Client.escape(string)
    end
  end
end
