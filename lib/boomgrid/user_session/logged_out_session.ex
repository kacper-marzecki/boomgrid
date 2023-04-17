defmodule Boom.UserSession.LoggedOutSession do
  use Ecto.Schema

  @primary_key {:session_id, :binary, autogenerate: false}

  schema "logged_out_session_ids" do
  end
end
