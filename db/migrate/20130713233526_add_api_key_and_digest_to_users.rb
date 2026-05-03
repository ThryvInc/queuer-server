class AddApiKeyAndDigestToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :api_key, :string
    add_column :users, :password_digest, :string
  end
end
