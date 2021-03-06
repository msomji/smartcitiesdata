defmodule Andi.SecretRetrieverTest do
  use ExUnit.Case
  use Placebo
  alias Andi.SecretRetriever
  import ExUnit.CaptureLog

  describe "retrieve/1" do
    setup do
      credentials = %{"username" => "admin", "password" => "1234"}

      %{
        dataset_id: 1,
        role: "andi-role",
        jwt: "asjdhfsa",
        credentials: credentials,
        vault: %Vault{engine: :secrets_engine, host: "http://vault:8200", auth: :auth_backend}
      }
    end

    test "retrieves credentials for auth0", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, values.jwt}
      allow Vault.new(any()), return: values.vault
      allow Vault.auth(values.vault, %{role: values.role, jwt: values.jwt}), return: {:ok, values.vault}

      allow Vault.read(values.vault, "secrets/smart_city/auth0/andi"),
        return: {:ok, values.credentials}

      assert SecretRetriever.retrieve_auth0_credentials() == {:ok, values.credentials}
    end

    test "returns error when kubernetes token file is not found" do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:error, :enoent}

      assert capture_log(fn ->
               assert SecretRetriever.retrieve_auth0_credentials() ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Secret token file not found"
    end

    test "returns error when vault service is unavailable", values do
      allow File.read("/var/run/secrets/kubernetes.io/serviceaccount/token"), return: {:ok, values.jwt}
      allow Vault.new(any()), return: values.vault

      allow Vault.auth(values.vault, %{role: values.role, jwt: values.jwt}),
        return: {:error, ["Something bad happened"]}

      allow Vault.read(values.vault, "secrets/smart_city/auth0/andi"),
        return: {:ok, values.credentials}

      assert capture_log(fn ->
               assert SecretRetriever.retrieve_auth0_credentials() ==
                        {:error, :retrieve_credential_failed}
             end) =~ "Something bad happened"
    end
  end
end
