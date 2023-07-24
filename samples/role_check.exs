Benchee.run(%{
  "role_check_string" => fn -> AshRbac.HasRole.match?(%{roles: ["admin"]},  nil, role: [roles: "admin"]) end,
  "role_check_atom" => fn -> AshRbac.HasRole.match?(%{roles: [:admin]}, nil, role: [roles: :admin]) end,
  "roles_check_string" => fn -> AshRbac.HasRole.match?(%{roles: ["admin"]}, nil,  role: [roles: ["admin", "user"]]) end,
  "roles_check_atom" => fn -> AshRbac.HasRole.match?(%{roles: [:admin]},nil, role: [roles: [:admin, :user]]) end,
})
