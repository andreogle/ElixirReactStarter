defmodule WebTemplateWeb.EmailTest do
  use ExUnit.Case, async: true

  # Email building logs an info line per send; keep test output clean.
  @moduletag :capture_log

  alias WebTemplateWeb.Email

  @recipient %{email: "person@example.com"}
  @token "raw-token-abc123"

  describe "confirmation_email/2" do
    test "addresses the recipient and ships both HTML and text bodies" do
      email = Email.confirmation_email(@recipient, @token)

      assert {_, "person@example.com"} = hd(email.to)
      assert email.subject =~ "Confirm"
      assert is_binary(email.html_body) and email.html_body != ""
      assert is_binary(email.text_body) and email.text_body != ""
    end

    test "embeds the confirmation URL with the raw token in both bodies" do
      email = Email.confirmation_email(@recipient, @token)

      assert email.html_body =~ "/confirm-email?token=#{@token}"
      assert email.text_body =~ "/confirm-email?token=#{@token}"
    end

    test "never leaks the token into the subject" do
      email = Email.confirmation_email(@recipient, @token)
      refute email.subject =~ @token
    end
  end

  describe "password_reset_email/2" do
    test "ships both bodies with the reset URL and keeps the token out of the subject" do
      email = Email.password_reset_email(@recipient, @token)

      assert {_, "person@example.com"} = hd(email.to)
      assert email.subject =~ "Reset"
      assert email.html_body =~ "/reset-password?token=#{@token}"
      assert email.text_body =~ "/reset-password?token=#{@token}"
      refute email.subject =~ @token
    end
  end
end
