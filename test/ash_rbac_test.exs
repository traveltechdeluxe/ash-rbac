defmodule AshRbacTest do
  use ExUnit.Case, async: true

  alias PolicyTestSupport.{Api, ChildResource, RootResource}

  @bypass_role :admin
  @user_role :user

  setup do
    root_resource = Api.create!(Ash.Changeset.for_create(RootResource, :create))

    child_resource =
      Api.create!(Ash.Changeset.for_create(ChildResource, :create, %{root_id: root_resource.id}))

    [root_resource: root_resource, child_resource: child_resource]
  end

  @tag :unit
  test "can select all attributes/relationships/calculations/aggregates in allow list", _ do
    assert {
             :ok,
             [
               %PolicyTestSupport.RootResource{
                 admin_only: nil,
                 admin_only_child: %Ash.NotLoaded{type: :relationship},
                 admin_only_children: %Ash.NotLoaded{type: :aggregate},
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: child,
                 children: 1,
                 created_at: nil,
                 id: _,
                 number: 1,
                 updated_at: nil,
                 aggregates: %{},
                 calculations: %{
                   {:__ash_fields_are_visible__, [:children]} => true,
                   {:__ash_fields_are_visible__, [:number]} => true
                 }
               }
             ]
           } =
             RootResource
             |> Ash.Query.select([:id])
             |> Ash.Query.load([:child, :number, :children])
             |> Api.read(actor: %{roles: [@user_role]})

    refute is_nil(child)
  end

  @tag :unit
  test "cannot select a attribute/relationship/calculation/aggregate not allow list", _ do
    # not specifying select is the same as selecting everything
    assert {
             :ok,
             [
               %PolicyTestSupport.RootResource{
                 admin_only: %Ash.ForbiddenField{field: :admin_only, type: :attribute},
                 admin_only_child: %Ash.NotLoaded{},
                 admin_only_children: %Ash.NotLoaded{},
                 admin_only_number: %Ash.NotLoaded{type: :calculation},
                 child: %Ash.NotLoaded{},
                 children: %Ash.NotLoaded{},
                 created_at: %Ash.ForbiddenField{field: :created_at, type: :attribute},
                 id: _,
                 number: %Ash.NotLoaded{},
                 updated_at: %Ash.ForbiddenField{field: :updated_at, type: :attribute},
                 aggregates: %{},
                 calculations: %{
                   {:__ash_fields_are_visible__, [:admin_only]} => false,
                   {:__ash_fields_are_visible__, [:created_at]} => false,
                   {:__ash_fields_are_visible__, [:updated_at]} => false
                 }
               }
             ]
           } =
             RootResource
             |> Api.read(actor: %{roles: [@user_role]})

    # selecting a forbidden field
    assert {
             :ok,
             [
               %PolicyTestSupport.RootResource{
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
               %PolicyTestSupport.RootResource{
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
               %PolicyTestSupport.RootResource{
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
             [_]
           } =
             RootResource
             |> Api.read(actor: %{roles: [@bypass_role]})
  end
end
