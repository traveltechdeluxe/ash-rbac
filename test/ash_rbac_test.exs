defmodule AshRbacTest do
  use ExUnit.Case, async: true

  alias AshRbacTest.{Api, ChildResource, RootResource, SharedResource}

  @bypass_role :super_admin
  @admin_role :admin
  @admin_string_role "admin"
  @user_role :user

  setup do
    root_resource = Api.create!(Ash.Changeset.for_create(RootResource, :create))
    shared_resource = Api.create!(Ash.Changeset.for_create(SharedResource, :create))

    child_resource =
      Api.create!(Ash.Changeset.for_create(ChildResource, :create, %{root_id: root_resource.id}))

    [
      root_resource: root_resource,
      child_resource: child_resource,
      shared_resource: shared_resource
    ]
  end

  @tag :unit
  test "can select all attributes/relationships/calculations/aggregates in allow list", _ do
    assert {
             :ok,
             [
               %RootResource{
                 admin_only: nil,
                 admin_only_child: %Ash.NotLoaded{type: :relationship},
                 admin_only_children: %Ash.NotLoaded{type: :aggregate},
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: %child{},
                 children: 1,
                 created_at: nil,
                 id: _,
                 number: 1,
                 updated_at: nil,
                 aggregates: %{},
                 calculations: %{}
               }
             ]
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:child, :number, :children])
             |> Api.read(actor: %{roles: [@user_role]})

    assert child == ChildResource
  end

  @tag :unit
  test "cannot select a attribute/relationship/calculation/aggregate not in allow list", _ do
    # not specifying select is the same as selecting everything
    assert {
             :ok,
             [
               %RootResource{
                 admin_only: %Ash.ForbiddenField{field: :admin_only, type: :attribute},
                 admin_only_child: %Ash.NotLoaded{type: :relationship},
                 admin_only_children: %Ash.NotLoaded{type: :aggregate},
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: %Ash.NotLoaded{type: :relationship},
                 children: %Ash.NotLoaded{type: :aggregate},
                 created_at: %Ash.ForbiddenField{field: :created_at, type: :attribute},
                 id: _,
                 number: %Ash.NotLoaded{type: :calculation},
                 updated_at: %Ash.ForbiddenField{field: :updated_at, type: :attribute},
                 aggregates: %{},
                 calculations: %{}
               }
             ]
           } =
             RootResource
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden field
    assert {
             :ok,
             [
               %RootResource{
                 admin_only: %Ash.ForbiddenField{field: :admin_only, type: :attribute},
                 admin_only_child: %Ash.NotLoaded{},
                 admin_only_children: %Ash.NotLoaded{},
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: %Ash.NotLoaded{},
                 children: %Ash.NotLoaded{},
                 created_at: nil,
                 id: _,
                 number: %Ash.NotLoaded{},
                 updated_at: nil,
                 aggregates: %{},
                 calculations: %{
                   {:__ash_fields_are_visible__, [:admin_only]} => false
                 }
               }
             ]
           } =
             RootResource
             |> Ash.Query.select([:admin_only])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden calculation
    assert {
             :ok,
             [
               %RootResource{
                 admin_only: nil,
                 admin_only_child: %Ash.NotLoaded{type: :relationship},
                 admin_only_children: %Ash.NotLoaded{type: :aggregate},
                 admin_only_number: %Ash.ForbiddenField{
                   field: :admin_only_number,
                   type: :calculation
                 },
                 child: %Ash.NotLoaded{type: :relationship},
                 children: %Ash.NotLoaded{type: :aggregate},
                 created_at: nil,
                 id: _,
                 number: %Ash.NotLoaded{type: :calculation},
                 updated_at: nil,
                 aggregates: %{},
                 calculations: %{
                   {:__ash_fields_are_visible__, [:admin_only_number]} => false
                 }
               }
             ]
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_number])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden aggregate
    assert {
             :ok,
             [
               %RootResource{
                 admin_only: nil,
                 admin_only_child: %Ash.NotLoaded{type: :relationship},
                 admin_only_children: %Ash.ForbiddenField{
                   field: :admin_only_children,
                   type: :aggregate
                 },
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: %Ash.NotLoaded{type: :relationship},
                 children: %Ash.NotLoaded{type: :aggregate},
                 created_at: nil,
                 id: _,
                 number: %Ash.NotLoaded{type: :calculation},
                 updated_at: nil,
                 aggregates: %{},
                 calculations: %{}
               }
             ]
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_children])
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden relationship
    assert {
             :error,
             %Ash.Error.Forbidden{}
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:admin_only_child])
             |> Api.read(actor: %{roles: [@user_role]})
  end

  @tag :unit
  test "bypass role can select everything", _ do
    assert {
             :ok,
             [
               %RootResource{
                 admin_only_number: 1,
                 number: 1,
                 admin_only_children: 1,
                 children: 1,
                 admin_only_child: %ChildResource{
                   __meta__: %Ecto.Schema.Metadata{state: :loaded},
                   id: admin_only_child_id,
                   root_id: root_id,
                   created_at: admin_only_child_created_at,
                   updated_at: admin_only_child_updated_at,
                   aggregates: %{},
                   calculations: %{},
                   __order__: nil
                 },
                 child: %ChildResource{
                   __meta__: %Ecto.Schema.Metadata{state: :loaded},
                   id: child_id,
                   root_id: root_id,
                   created_at: child_created_at,
                   updated_at: child_updated_at,
                   aggregates: %{},
                   calculations: %{},
                   __order__: nil
                 },
                 __meta__: %Ecto.Schema.Metadata{state: :loaded},
                 id: root_id,
                 admin_only: 2,
                 created_at: created_at,
                 updated_at: updated_at,
                 aggregates: %{},
                 calculations: %{},
                 __order__: nil
               }
             ]
           } =
             RootResource
             |> Ash.Query.for_read(:read)
             |> Ash.Query.load([
               :child,
               :admin_only_child,
               :children,
               :admin_only_children,
               :number,
               :admin_only_number
             ])
             |> Api.read(actor: %{roles: [@bypass_role]})

    assert {:ok, _} = UUID.info(root_id)
    assert {:ok, _} = UUID.info(admin_only_child_id)
    assert {:ok, _} = UUID.info(child_id)

    assert DateTime.to_string(created_at)
    assert DateTime.to_string(updated_at)
    assert DateTime.to_string(admin_only_child_created_at)
    assert DateTime.to_string(admin_only_child_updated_at)
    assert DateTime.to_string(child_created_at)
    assert DateTime.to_string(child_updated_at)
  end

  @tag :unit
  test "bypass role can use all actions", _ do
    assert {:ok, resource} =
             RootResource
             |> Ash.Changeset.for_create(:create, %{}, actor: %{roles: [@bypass_role]})
             |> Api.create(actor: %{roles: [@bypass_role]})

    assert {:ok, [_, _]} =
             RootResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@bypass_role]})
             |> Ash.Query.sort([:created_at])
             |> Api.read(actor: %{roles: [@bypass_role]})

    assert {:ok, resource} =
             resource
             |> Ash.Changeset.for_update(:update, %{}, actor: %{roles: [@bypass_role]})
             |> Api.update(actor: %{roles: [@bypass_role]})

    assert :ok ==
             resource
             |> Ash.Changeset.for_destroy(:destroy, actor: %{roles: [@bypass_role]})
             |> Api.destroy(actor: %{roles: [@bypass_role]})

    assert {:ok, [_]} =
             RootResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@bypass_role]})
             |> Ash.Query.sort([:created_at])
             |> Api.read(actor: %{roles: [@bypass_role]})
  end

  @tag :unit
  test "admin role can only create and read", _ do
    assert {:ok, %{admin_only: 5} = resource} =
             RootResource
             |> Ash.Changeset.for_create(:create, %{admin_only: 5}, actor: %{roles: [@admin_role]})
             |> Api.create(actor: %{roles: [@admin_role]})

    assert {:ok, [%{admin_only: 2}, %{admin_only: 5}]} =
             RootResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@admin_role]})
             |> Ash.Query.sort([:created_at])
             |> Api.read(actor: %{roles: [@admin_role]})

    assert {:error, %Ash.Error.Forbidden{}} =
             resource
             |> Ash.Changeset.for_update(:update, %{}, actor: %{roles: [@admin_role]})
             |> Api.update(actor: %{roles: [@admin_role]})

    assert {:error, %Ash.Error.Forbidden{}} =
             resource
             |> Ash.Changeset.for_destroy(:destroy, actor: %{roles: [@admin_role]})
             |> Api.destroy(actor: %{roles: [@admin_role]})
  end

  @tag :unit
  test "user role can only read", %{root_resource: resource} do
    assert {:ok, [_]} =
             RootResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@user_role]})
             |> Ash.Query.sort([:created_at])
             |> Api.read(actor: %{roles: [@user_role]})

    assert {:error, %Ash.Error.Forbidden{}} =
             RootResource
             |> Ash.Changeset.for_create(:create, %{}, actor: %{roles: [@user_role]})
             |> Api.create(actor: %{roles: [@user_role]})

    assert {:error, %Ash.Error.Forbidden{}} =
             resource
             |> Ash.Changeset.for_update(:update, %{}, actor: %{roles: [@user_role]})
             |> Api.update(actor: %{roles: [@user_role]})

    assert {:error, %Ash.Error.Forbidden{}} =
             resource
             |> Ash.Changeset.for_destroy(:destroy, actor: %{roles: [@user_role]})
             |> Api.destroy(actor: %{roles: [@user_role]})
  end

  @tag :wip
  test "`:admin` and \"admin\" have read access", _ do
    assert {:ok, [%{basic_field: 2}]} =
             SharedResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@admin_role]})
             |> Api.read(actor: %{roles: [@admin_role]})

    assert {:ok, [%{basic_field: 2}]} =
             SharedResource
             |> Ash.Query.for_read(:read, actor: %{roles: [@admin_string_role]})
             |> Api.read(actor: %{roles: [@admin_string_role]})
  end
end
