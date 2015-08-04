require 'mysql2'

module MysqlUsers
  class User
    attr_reader :db_client
    attr_reader :e_username
    attr_reader :e_scope

    def initialize(db_client, options={})
      @db_client = db_client
      @e_username = escape(options[:username])
      @e_scope = escape(options[:scope])
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

    private

    def create
      # TODO: add 'IDENTIFIED BY' for password
      sql = "CREATE USER '#{e_username}'@'#{e_scope}'"
      db_client.query(sql)
    end

    def escape(string)
      Mysql2::Client.escape(string)
    end
  end
end
