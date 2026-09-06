const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'manassehavettey@gmail.com',
    pass: 'kqbapajjynujydyu'
  }
});

console.log("⏳ Testing Email Server Connection...");

transporter.verify(function (error, success) {
  if (error) {
    console.log("❌ Connection Error:");
    console.log(error);
  } else {
    console.log("✅ Server is ready to take our messages!");

    // Attempt to send a test email to self
    const mailOptions = {
      from: '"CommunityWatch Security" <manassehavettey@gmail.com>',
      to: 'manassehavettey@gmail.com',
      subject: '🔧 SERVER_DIAGNOSTIC: EMAIL_LINK_TEST',
      text: 'The email server is functioning correctly.',
      html: '<h1>✅ CONNECTION_SECURE</h1><p>The backend email relay is online.</p>'
    };

    transporter.sendMail(mailOptions, (err, info) => {
      if (err) {
        console.log("❌ Failed to send test email:");
        console.log(err);
      } else {
        console.log("📧 Test email sent successfully!");
        console.log("Result:", info.response);
      }
      process.exit();
    });
  }
});
