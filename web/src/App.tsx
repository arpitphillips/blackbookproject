import { OnboardingForm } from './OnboardingForm';

export function App() {
  return (
    <div className="page">
      <header className="hero">
        <div className="hero-inner">
          <div className="brand">Blackbook</div>
          <h1>Get discovered for the work you do best.</h1>
          <p className="lede">
            Blackbook is the structured directory of the creative industry. Create your profile
            once and become discoverable to the people hiring for your craft — by category,
            location, services and more.
          </p>
          <ul className="benefits">
            <li>Free to join</li>
            <li>Reviewed for quality</li>
            <li>Found by clients searching your speciality</li>
          </ul>
        </div>
      </header>

      <main className="content">
        <OnboardingForm />
      </main>

      <footer className="footer">
        <span>© {new Date().getFullYear()} Blackbook</span>
        <span>The canonical directory of the creative industry.</span>
      </footer>
    </div>
  );
}
