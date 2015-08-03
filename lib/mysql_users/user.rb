require 'mysql2'

module MysqlUsers
  class User
    attr_reader :username
    attr_reader :db_client
    attr_reader :scope

    def initialize(db_client, options={})
      @db_client = db_client
      @username = options[:username]
      @scope = options[:scope]
    end

    def exists?
      result = db_client.query(
        "SELECT User, Scope FROM mysql.user WHERE "\
        "User='#{escape(username)}' AND Scope='#{escape(scope)}'"
      )
      result.count != 0
    end

    private

    def escape(string)
      Mysql2::Client.escape(string)
    end
  end
end
