defmodule Auth.Auth0.SecretFetcherTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  alias Auth.Auth0.SecretFetcher

  @jwks_response %{
                   "keys" => [
                     %{
                       "alg" => "RS256",
                       "e" => "AQAB",
                       "kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ",
                       "kty" => "RSA",
                       "n" =>
                         "v2sPefYhGRLtNg65LivKuqaHtIJo169qEYt7q3EOkfekWKsqqEQBO2BG_RCuZbQ_xW7dzfsthKks7RphP1XxqUiKaEMorMm7WbzjlGmNlaFYjsTrzJ5scATwQvbc7Z8cUYilZmojf2jTt7GUya3Ko6u6KxD_1ixsJSBRNaFy7lizlxoE7sRbPJZw1mVOhHUXLio1AvpOjjWeBVpFfXxfLT2-1_KMxayVwAyIppfOqVflQGeS0Eqz8eWK7vktMvOe1TRSoQEfChWMxg3Q6iDP22m0pgc9QCeVeHBI82q0Cc7NHxPSTWHswVoGqjBFGBrZWoq2qDzBVltwxlV-n2mryQ",
                       "use" => "sig",
                       "x5c" => [
                         "MIIDFTCCAf2gAwIBAgIJeoRXP4wlaH/yMA0GCSqGSIb3DQEBCwUAMCgxJjAkBgNVBAMTHXNtYXJ0Y29sdW1idXNvcy1kZXYuYXV0aDAuY29tMB4XDTE5MDkyNTE5MzMxNVoXDTMzMDYwMzE5MzMxNVowKDEmMCQGA1UEAxMdc21hcnRjb2x1bWJ1c29zLWRldi5hdXRoMC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC/aw959iEZEu02DrkuK8q6poe0gmjXr2oRi3urcQ6R96RYqyqoRAE7YEb9EK5ltD/Fbt3N+y2EqSztGmE/VfGpSIpoQyisybtZvOOUaY2VoViOxOvMnmxwBPBC9tztnxxRiKVmaiN/aNO3sZTJrcqjq7orEP/WLGwlIFE1oXLuWLOXGgTuxFs8lnDWZU6EdRcuKjUC+k6ONZ4FWkV9fF8tPb7X8ozFrJXADIiml86pV+VAZ5LQSrPx5Yru+S0y857VNFKhAR8KFYzGDdDqIM/babSmBz1AJ5V4cEjzarQJzs0fE9JNYezBWgaqMEUYGtlairaoPMFWW3DGVX6faavJAgMBAAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFH0IhwzcfpDAseqmrpnd5+G7vGLYMA4GA1UdDwEB/wQEAwIChDANBgkqhkiG9w0BAQsFAAOCAQEAj4z/PmYTLJGDFak6i3dsSO6VVm7ctN0oKHxEOi8H1vCWk6xq9RLrCNGM/TssDsfoZw1CY0nvRRankNOv77c1isIXSWwIR4Bh9RV3qBx02CqQbMid7ODTiKA3vNPbPeYUEFtjV+I5qIrBN+B6wzdQnUp9fZZPVHRiLALamuRCLmj0BngIQA3Gx8N6uRtKxp5MaeG6NQJXT9Qt/4ZzbiJakYSRhsktC18fgty7p86KkA8+KBJAmC4dRgGOwC28rx+SAcRFKE+QrtNp3VbL6kgtHYMmQm9JvOSjdSRZs54hkrFpYlFOtbVkGzpqzOLwZ1K03gcnQv3dawP0tTwdMxu81g=="
                       ],
                       "x5t" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"
                     }
                   ]
                 }
                 |> Jason.encode!()

  describe "valid jwks key store" do
    setup do
      Auth.Auth0.CachedJWKS.clear()

      bypass = Bypass.open()

      allow(SecretFetcher.fetch_verifying_secret(any(), any(), any()),
        exec: fn _, %{"kid" => kid}, _ ->
          Auth.Auth0.CachedJWKS.get_key("http://localhost:#{bypass.port}/", kid)
        end
      )

      Bypass.expect_once(bypass, "GET", "/.well-known/jwks.json", fn conn ->
        Plug.Conn.resp(conn, 200, @jwks_response)
      end)

      [issuer: "localhost:#{bypass.port}"]
    end

    test "gives requested key", %{issuer: issuer} do
      secret =
        SecretFetcher.fetch_verifying_secret(
          __MODULE__,
          %{"kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"},
          issuer: issuer
        )

      assert {:ok,
              %JOSE.JWK{
                fields: %{"kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"}
              }} = secret
    end

    test "returns error message if no key is found in the store", %{issuer: issuer} do
      error_message =
        SecretFetcher.fetch_verifying_secret(__MODULE__, %{"kid" => "does_not_exist"},
          issuer: issuer
        )

      assert {:error, "no key for kid: does_not_exist"} = error_message
    end
  end

  test "caches key fetching for subsequent calls" do
    Auth.Auth0.CachedJWKS.clear()
    fake_jwks = %{"keys" => [%{"kid" => "cat"}]} |> Jason.encode!()
    allow(HTTPoison.get(any()), return: {:ok, %{body: fake_jwks}})

    allow(SecretFetcher.fetch_verifying_secret(any(), any(), any()),
      exec: fn _, %{"kid" => kid}, _ ->
        Auth.Auth0.CachedJWKS.get_key("http://localhost:doesntmatter/", kid)
      end
    )

    allow(Auth.Auth0.CachedJWKS.key_from_jwks(any(), any()), return: {:ok, "blah"})

    SecretFetcher.fetch_verifying_secret(
      __MODULE__,
      %{"kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"},
      issuer: "localhost:doesntmatter"
    )

    SecretFetcher.fetch_verifying_secret(
      __MODULE__,
      %{"kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"},
      issuer: "localhost:doesntmatter"
    )

    assert_called(HTTPoison.get(any()), once())
  end

  describe "invalid jwks key store" do
    test "returns error given by issuer" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/.well-known/jwks.json", fn conn ->
        Plug.Conn.resp(conn, 404, "Not found")
      end)

      allow(SecretFetcher.fetch_verifying_secret(any(), any(), any()),
        exec: fn _, %{"kid" => kid}, _ ->
          Auth.Auth0.CachedJWKS.get_key("http://localhost:#{bypass.port}/", kid)
        end
      )

      error_message =
        SecretFetcher.fetch_verifying_secret(
          __MODULE__,
          %{"kid" => "RDVCQjg5MDhENzQ1RTIyMDk1OUI1NEYxODU5MTgwQkVGNDREODlDOQ"},
          issuer: "localhost:#{bypass.port}"
        )

      assert {:error, _} = error_message
    end
  end
end
