simple mysql grant management inspired by [this chef recipe](https://github.com/opscode-cookbooks/database/blob/master/libraries/provider_database_mysql_user.rb)

# Installation

It's still being developed so it's not on rubygems right now. Add this to your
Gemfile:

```
gem 'mysql_users', git: 'https://github.com/margueritepd/ruby_mysql_users.git'
```

# Usage

The user object takes a database client as part of its constructor. You can use
the mysql2 database client, or you can write your own - as long as it responds
to `query` and `escape`, you're good.

If using the `mysql2` client, you should probably make sure you close the
connection when you're done manipulating the user object.

In the constructor, you want to also pass the user's username and hosts from
which it can log into.

You can optionally pass a password.

eg:

```ruby
require 'mysql_users'
require 'mysql2'

begin
  db = Mysql2::Client.new(
    host: "localhost",
    username: "root",
  )

  ['%', 'localhost'].each do |host|
    user = MysqlUsers::User.new(
      db,
      {
        username: 'marguerite',
        host: host,
        password: 'foo',
      }
    )
    user.create  # won't complain if user exists already
    user.grant({
      grants: ['ALL PRIVILEGES'],
      database: 'web',
      table: 'auth',
    })
    user.revoke({
      grants: ['SELECT'],
      database: 'web',
      table: 'auth',
    })
    user.drop
  end
rescue => e
  puts e
  raise e
ensure
  db.close unless db.nil?
end
```

# Testing

```
bundle exec rake
```

# Creating a new package

```
bundle exec rake build
# new gem is in pkg/
```
