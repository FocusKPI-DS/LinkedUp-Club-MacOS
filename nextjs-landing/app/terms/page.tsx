import styles from './page.module.css'
import navStyles from '../page.module.css'
import Link from 'next/link'

export default function TermsPage() {
  return (
    <div className={navStyles.wrapper}>
      {/* Navigation */}
      <nav className={navStyles.nav}>
        <div className={navStyles.navContainer}>
          <Link href="/" className={navStyles.logo}>Lona</Link>
          <div className={navStyles.navLinks}>
            <a href="/#features">Features</a>
            <a href="/#how-it-works">How It Works</a>
            <a href="/#pricing">For SMBs</a>
            <a href="/#faq">FAQ</a>
          </div>
          <div className={navStyles.ctaButtons}>
            <a href="/#download" className={navStyles.primaryButton}>Get Started</a>
          </div>
        </div>
      </nav>

      <div className={styles.container}>
        <div className={styles.content}>
        <h1 className={styles.title}>Lona Club — Terms of Use</h1>
        <p className={styles.lastUpdated}>Last Updated: November 7, 2025</p>

        <div className={styles.intro}>
          <p>
            Welcome to Lona Club ("Lona," "we," "our," or "us"). By accessing or using our website, Mac, iOS, or web applications (the "Service"), you agree to be bound by these Terms of Use. Please read them carefully.
          </p>
        </div>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>1. Overview</h2>
          <p>
            Lona Club provides a centralized workspace that connects your communication, calendar, and productivity tools (e.g., Slack, Gmail, Google Calendar, Teams). The Service helps you manage messages, tasks, and workspaces in one intelligent hub.
          </p>
          <p>
            By using Lona, you represent that you are at least 18 years old and authorized to enter into this agreement.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>2. Use of the Service</h2>
          <ul className={styles.list}>
            <li>You may use Lona only for lawful purposes and in accordance with these Terms.</li>
            <li>You agree not to misuse the Service, attempt unauthorized access, or interfere with its functionality.</li>
            <li>You are responsible for maintaining the confidentiality of your account and credentials.</li>
            <li>We reserve the right to suspend or terminate accounts that violate these Terms.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>3. Subscriptions and Payment</h2>
          <ul className={styles.list}>
            <li>Some features may require a paid plan.</li>
            <li>By subscribing, you authorize us to charge your payment method for recurring fees unless canceled before the renewal date.</li>
            <li>All fees are non-refundable except as required by law.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>4. Third-Party Integrations</h2>
          <ul className={styles.list}>
            <li>Lona connects with third-party apps (e.g., Slack, Gmail, Google Calendar, Microsoft Teams).</li>
            <li>Your use of these integrations is governed by their respective terms and privacy policies.</li>
            <li>We do not control or take responsibility for third-party services.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>5. Intellectual Property</h2>
          <ul className={styles.list}>
            <li>All trademarks, software, and content within Lona are the property of Lona Club or its licensors.</li>
            <li>You may not copy, modify, or distribute any part of the Service without our written consent.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>6. Disclaimer and Limitation of Liability</h2>
          <ul className={styles.list}>
            <li>The Service is provided "as is" and "as available."</li>
            <li>We make no warranties, express or implied, about reliability, availability, or fitness for a particular purpose.</li>
            <li>To the maximum extent permitted by law, Lona Club is not liable for indirect, incidental, or consequential damages arising from your use of the Service.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>7. Termination</h2>
          <ul className={styles.list}>
            <li>You may stop using Lona at any time.</li>
            <li>We may suspend or terminate your access if you violate these Terms or engage in harmful behavior toward the platform.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>8. Changes to These Terms</h2>
          <ul className={styles.list}>
            <li>We may update these Terms from time to time.</li>
            <li>Continued use after changes means you accept the revised Terms.</li>
            <li>We'll post the latest version on our website.</li>
          </ul>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>9. Contact</h2>
          <p>
            For questions about these Terms, contact:
          </p>
          <p className={styles.contact}>
            📧 <a href="mailto:lona_support@focuskpi.com">lona_support@focuskpi.com</a>
          </p>
        </section>
        </div>
      </div>

      {/* Footer */}
      <footer className={navStyles.footer}>
        <div className={navStyles.footerContainer}>
          <div className={navStyles.footerContent}>
            <div className={navStyles.footerBrand}>
              <div className={navStyles.footerLogo}>Lona</div>
              <p className={navStyles.footerDescription}>
                All-in-one AI workspace for SMBs. Privacy-first, built for modern teams.
              </p>
            </div>
            <div className={navStyles.footerLinks}>
              <div className={navStyles.footerLinksTitle}>Quick Links</div>
              <a href="/#support">Support</a>
              <a href="/#docs">Documentation</a>
              <a href="/terms">Terms of Use</a>
              <a href="/privacy">Privacy Policy</a>
            </div>
          </div>
          <div className={navStyles.footerBottom}>
            <p className={navStyles.footerTagline}>
              Privacy-first | Built with ❤️ in the USA
            </p>
            <div className={navStyles.footerSocial}>
              <a href="#twitter" aria-label="Twitter">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M23 3C22.0424 3.67548 20.9821 4.19211 19.88 4.53C19.2942 3.83751 18.5307 3.34669 17.689 3.12393C16.8472 2.90116 15.9561 2.95791 15.19 3.29C13.84 3.83 12.89 5.16 12.89 6.78V7.53C9.3 7.58 6.14 5.88 4 3C4 3 -0.91 13.17 8.71 17.61C6.62 19.31 4.26 20.27 2 20C11.24 25.34 22.5 20 22.5 9.5C22.4996 9.22146 22.4769 8.94359 22.43 8.67C23.4257 7.92521 24.23 6.99833 24.79 5.95L23 3Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
              <a href="#linkedin" aria-label="LinkedIn">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M16 8C17.5913 8 19.1174 8.63214 20.2426 9.75736C21.3679 10.8826 22 12.4087 22 14V21H18V14C18 13.4696 17.7893 12.9609 17.4142 12.5858C17.0391 12.2107 16.5304 12 16 12C15.4696 12 14.9609 12.2107 14.5858 12.5858C14.2107 12.9609 14 13.4696 14 14V21H10V14C10 12.4087 10.6321 10.8826 11.7574 9.75736C12.8826 8.63214 14.4087 8 16 8Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M6 9H2V21H6V9Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M4 6C5.10457 6 6 5.10457 6 4C6 2.89543 5.10457 2 4 2C2.89543 2 2 2.89543 2 4C2 5.10457 2.89543 6 4 6Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
              <a href="#github" aria-label="GitHub">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M9 19C4 20.5 4 16.5 2 16M22 16V20C22 20.5304 21.7893 21.0391 21.4142 21.4142C21.0391 21.7893 20.5304 22 20 22H16C15.4696 22 14.9609 21.7893 14.5858 21.4142C14.2107 21.0391 14 20.5304 14 20V16C14 15.4696 14.2107 14.9609 14.5858 14.5858C14.9609 14.2107 15.4696 14 16 14H20C20.5304 14 21.0391 14.2107 21.4142 14.5858C21.7893 14.9609 22 15.4696 22 16Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </a>
            </div>
          </div>
          <p className={navStyles.footerCopyright}>© 2025 Lona. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

