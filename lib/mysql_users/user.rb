module MysqlUsers
  class User
    def initialize(database, options={})
      @database = database
      @username = options[:username]
      @scope = options[:scope]
      @grants = options[:grants]
    end
  end
end
