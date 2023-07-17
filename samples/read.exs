alias AshRbacTest.{Api, ChildResource, RootResource, SharedResource}


root_resource = Api.create!(Ash.Changeset.for_create(RootResource, :create))
Api.create!(Ash.Changeset.for_create(SharedResource, :create))
      Api.create!(Ash.Changeset.for_create(ChildResource, :create, %{root_id: root_resource.id}))

Benchee.run(%{
  "read" => fn ->
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:child, :number, :children])
             |> Api.read(actor: %{roles: [:user]})
  end
})
