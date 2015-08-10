module MysqlUsers
  class User
    attr_reader :db_client
    attr_reader :e_username
    attr_reader :e_host

    def initialize(db_client, options={})
      @db_client = db_client
      @e_username = escape(options.fetch(:username))
      @e_host = escape(options.fetch(:host))
      p = options[:password]
      @e_password = p ? escape(p) : nil
    end

    def exists?
      query = "SELECT User, Host FROM mysql.user WHERE "\
        "User='#{e_username}' AND Host='#{e_host}'"
      result = db_client.query(query)
      result.count != 0
    end

    def create
      return if exists?
      create_without_check
    end

    def drop
      return unless exists?
      sql = "DROP USER #{user_address}"
      db_client.query(sql)
    end

    # TODO should this be its own class?
    def grant(options)
      db = backtick_or_star(options[:database], 'give grants to')
      table = backtick_or_star(options[:table], 'give grants to')
      grants = options.fetch(:grants)
      verify_grants_sanitized(grants, 'give')

      sql = "GRANT #{grants.join(',')}"
      sql += " ON #{db}.#{table}"
      sql += " TO #{user_address}"
      sql += " WITH GRANT OPTION" if options.fetch(:with_grant_option, false)

      db_client.query(sql)
    end

    def revoke(options)
      db = backtick_or_star(options[:database], 'revoke grants from')
      table = backtick_or_star(options[:table], 'revoke grants from')
      grants = options.fetch(:grants)
      verify_grants_sanitized(grants, 'revoke')
      sql = "REVOKE #{grants.join(',')}"
      sql += " ON #{db}.#{table}"
      sql += " FROM #{user_address}"
      db_client.query(sql)
    end

    private

    def user_address
      "'#{e_username}'@'#{e_host}'"
    end

    def verify_grants_sanitized(grants, verb)
      unless grants.all?{ |grant| /^[a-zA-Z ]+$/.match(grant) }
        raise "grants should match [a-zA-Z ]. Refusing to #{verb} grants"
      end
      if grants.empty?
        raise 'provided list of grants must be non-empty'
      end
    end

    def backtick_or_star(name, verb)
      return '*' unless name
      backtick_error = "refusing to #{verb} an entity "\
        'whose name contains backticks'
      raise backtick_error if /`/.match(name)
      "`#{escape(name)}`"
    end

    def has_password?
      !@e_password.nil?
    end

    def create_without_check
      sql = "CREATE USER #{user_address}"
      sql += " IDENTIFIED BY '#{@e_password}'" if has_password?
      db_client.query(sql)
    end

    def escape(string)
      db_client.escape(string)
    end
  end
end
