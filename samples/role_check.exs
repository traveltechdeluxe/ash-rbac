Benchee.run(%{
  "role_check_string" => fn -> AshRbac.HasRole.match?(%{roles: ["admin"]},  nil, role: "admin") end,
  "role_check_atom" => fn -> AshRbac.HasRole.match?(%{roles: [:admin]}, nil, role: :admin) end,
  "roles_check_string" => fn -> AshRbac.HasRole.match?(%{roles: ["admin"]}, nil,  role: ["admin", "user"]) end,
  "roles_check_atom" => fn -> AshRbac.HasRole.match?(%{roles: [:admin]},nil, role: [:admin, :user]) end,
})
