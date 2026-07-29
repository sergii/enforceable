# Fixing the demo

The intentional bug is the scope in `demo.rb`. Replace its `resolve` line with:

```ruby
def resolve
  @relation.where(workspace_id: @user.workspace_id)
           .joins(:requisition)
           .where("requisitions.confidential = ? OR ?", false, @user.hiring_committee?)
end
```

The point rule and scope then agree for committee members, recruiters, and outsiders.
