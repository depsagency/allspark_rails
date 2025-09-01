class TestMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.test_mailer.test_email.subject
  #
  def test_email(to_email = "test@example.com")
    @greeting = "Hi there!"
    @message = "This is a test email to verify letter_opener_web is working correctly."

    mail(
      to: to_email,
      subject: "Test Email - letter_opener_web"
    )
  end
end
