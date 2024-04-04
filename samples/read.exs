alias AshRbacTest.{ChildResource, RootResource, SharedResource}


root_resource = Ash.create!(Ash.Changeset.for_create(RootResource, :create), authorize?: false)
Ash.create!(Ash.Changeset.for_create(SharedResource, :create), authorize?: false)
Ash.create!(Ash.Changeset.for_create(ChildResource, :create, %{root_id: root_resource.id}), authorize?: false)

Benchee.run(%{
  "read" => fn ->
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:child, :number, :children])
             |> Ash.read(actor: %{roles: [:user]})
  end
}, profile_after: true)
