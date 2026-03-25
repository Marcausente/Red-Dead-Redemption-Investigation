import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';
import PlaceholderPage from './pages/PlaceholderPage';
import Welcome from './pages/Welcome';
import Cases from './pages/Cases';
import CaseDetail from './pages/CaseDetail'; 
import Gangs from './pages/Gangs'; 
import Incidents from './pages/Incidents'; 
import Personnel from './pages/Personnel';
import PersonnelDetail from './pages/PersonnelDetail';
import Documentation from './pages/Documentation';
import CrimeMap from './pages/CrimeMap'; 
import Wanted from './pages/Wanted';
import MainLayout from './components/MainLayout';
import { PresenceProvider } from './contexts/PresenceContext';
import './index.css';

function App() {
  return (
    <PresenceProvider>
      <Router>
        <Routes>
          <Route path="/" element={<Login />} />
          <Route path="/welcome" element={<Welcome />} />

          <Route element={<MainLayout />}>
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/documentation" element={<Documentation />} />
            <Route path="/cases" element={<Cases />} />
            <Route path="/cases/:id" element={<CaseDetail />} />
            <Route path="/gangs" element={<Gangs />} />
            <Route path="/incidents" element={<Incidents />} />
            <Route path="/wanted" element={<Wanted />} />
            <Route path="/crimemap" element={<CrimeMap />} />
            <Route path="/personnel" element={<Personnel />} />
            <Route path="/personnel/:id" element={<PersonnelDetail />} />
            <Route path="/profile" element={<Profile />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Router>
    </PresenceProvider>
  );
}

export default App;
