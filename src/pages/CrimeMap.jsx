import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { supabase } from '../supabaseClient';

// Use the new RDR map image instead of GTAV
import MapImage from '../assets/mapardr.jpg';
import './CrimeMapRDR.css';

// Fix typical Leaflet icons
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
    iconUrl: icon,
    shadowUrl: iconShadow,
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});
L.Marker.prototype.options.icon = DefaultIcon;

export default function CrimeMap() {
    const mapContainerRef = useRef(null);
    const mapInstanceRef = useRef(null);
    const layerGroupRef = useRef(null);
    const drawingLayerRef = useRef(null);

    // State
    const [zones, setZones] = useState([]);
    const [mapReady, setMapReady] = useState(false);
    const [authorized, setAuthorized] = useState(false);
    const [mode, setMode] = useState('view'); // 'view', 'draw'
    const [drawingPoints, setDrawingPoints] = useState([]);

    // Form State
    const [tempZoneData, setTempZoneData] = useState({ name: '', description: '', color: '#8b0000' });
    const [showModal, setShowModal] = useState(false);
    const [editingZoneId, setEditingZoneId] = useState(null); // ID if editing, null if creating

    // Refs for closure access inside map events
    const modeRef = useRef(mode);
    useEffect(() => { modeRef.current = mode; }, [mode]);
    const drawingPointsRef = useRef(drawingPoints);
    useEffect(() => { drawingPointsRef.current = drawingPoints; }, [drawingPoints]);

    useEffect(() => {
        checkAuth();
        fetchZones();
    }, []);

    const checkAuth = async () => {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
            const { data: profile } = await supabase
                .from('users')
                .select('rol')
                .eq('id', user.id)
                .single();
                
            if (profile && ['Coordinador', 'Jefatura', 'Agente BOI', 'Administrador'].includes(profile.rol)) {
                setAuthorized(true);
            }
        }
    };

    const fetchZones = async () => {
        const { data } = await supabase.rpc('get_map_zones');
        setZones(data || []);
    };

    useEffect(() => {
        let isMounted = true;
        if (!mapInstanceRef.current && mapContainerRef.current) {
            
            const img = new Image();
            img.src = MapImage;
            img.onload = () => {
                if (!isMounted || !mapContainerRef.current || mapInstanceRef.current) return;
                
                // Fetch native resolution of the map so it perfectly retains its correct Aspect Ratio
                const w = img.naturalWidth || 4096;
                const h = img.naturalHeight || 4096;
                const bounds = [[0, 0], [h, w]];

                const map = L.map(mapContainerRef.current, {
                    crs: L.CRS.Simple,
                    minZoom: -2.5,
                    maxZoom: 3,
                    zoom: -1.5,
                    zoomSnap: 0.5,
                    zoomDelta: 0.5,
                    center: [h / 2, w / 2],
                    zoomControl: false, 
                    attributionControl: false,
                    maxBounds: bounds, 
                    maxBoundsViscosity: 1.0,
                    bounceAtZoomLimits: false
                });

                // Blend the sharp background edges with the paper map color
                mapContainerRef.current.style.background = '#d0b58f';

                L.imageOverlay(MapImage, bounds).addTo(map);
                
                // Start with a centered zoom instead of fitBounds (which causes distant zoom out)
                map.setView([h / 2, w / 2], -1.5);

                layerGroupRef.current = L.layerGroup().addTo(map);
                drawingLayerRef.current = L.layerGroup().addTo(map);

                map.on('click', (e) => {
                    if (modeRef.current === 'draw') {
                        const newPoint = [e.latlng.lat, e.latlng.lng];
                        setDrawingPoints(prev => [...prev, newPoint]);
                    }
                });

                map.on('contextmenu', (e) => {
                    if (modeRef.current === 'draw') {
                        e.originalEvent.preventDefault();
                        setDrawingPoints(prev => prev.slice(0, -1));
                    }
                });

                // Event delegation for popup buttons
                const container = map.getContainer();
                container.addEventListener('click', (e) => {
                    if (e.target.classList.contains('delete-zone-btn')) {
                        const id = e.target.getAttribute('data-id');
                        handleDeleteZone(id);
                    }
                    if (e.target.classList.contains('edit-zone-btn')) {
                        const id = e.target.getAttribute('data-id');
                        const event = new CustomEvent('edit-zone-click', { detail: { id } });
                        window.dispatchEvent(event);
                    }
                });

                mapInstanceRef.current = map;
                setMapReady(true);
            };
        }

        return () => {
            isMounted = false;
            if (mapInstanceRef.current) {
                mapInstanceRef.current.remove();
                mapInstanceRef.current = null;
            }
        };
    }, []);

    // Listen for custom event to trigger edit
    useEffect(() => {
        const handleEditEvent = (e) => {
            const id = e.detail.id;
            const zoneToEdit = zones.find(z => z.id === id);
            if (zoneToEdit) prepareEdit(zoneToEdit);
        };
        window.addEventListener('edit-zone-click', handleEditEvent);
        return () => window.removeEventListener('edit-zone-click', handleEditEvent);
    }, [zones]);

    // RENDER ZONES
    useEffect(() => {  // RENDER ZONES
        if (mapInstanceRef.current && layerGroupRef.current) {
            layerGroupRef.current.clearLayers();

            zones.forEach(zone => {
                const poly = L.polygon(zone.coordinates, {
                    color: zone.color,
                    fillColor: zone.color,
                    fillOpacity: 0.35,
                    weight: 2
                });

                let popupHTML = `
                    <div class="rdr-map-popup-title">${zone.name}</div>
                    <div class="rdr-map-popup-desc">${zone.description || 'Sin documentos disponibles acerca de esta zona.'}</div>
                `;

                if (authorized) {
                    popupHTML += `
                        <div style="display: flex; gap: 8px; margin-top: 15px;">
                            <button class="rdr-map-btn edit-zone-btn" data-id="${zone.id}">Escribir</button>
                            <button class="rdr-map-btn rdr-map-btn-delete delete-zone-btn" data-id="${zone.id}">Borrar</button>
                        </div>
                    `;
                }

                poly.bindPopup(popupHTML, {
                    className: 'rdr-map-popup',
                    minWidth: 220
                });

                poly.on('mouseover', function () { this.setStyle({ fillOpacity: 0.6, weight: 3 }); });
                poly.on('mouseout', function () { this.setStyle({ fillOpacity: 0.35, weight: 2 }); });

                poly.addTo(layerGroupRef.current);
            });
        }
    }, [zones, authorized, mapReady]);

    // RENDER DRAWING
    useEffect(() => {
        if (mapInstanceRef.current && drawingLayerRef.current) {
            drawingLayerRef.current.clearLayers();

            if (mode === 'draw' && drawingPoints.length > 0) {
                drawingPoints.forEach(pt => {
                    L.circleMarker(pt, { color: '#3b2b1d', radius: 5, fillOpacity: 1 }).addTo(drawingLayerRef.current);
                });

                if (drawingPoints.length > 1) {
                    L.polyline(drawingPoints, { color: '#3b2b1d', dashArray: '5, 10', weight: 3 }).addTo(drawingLayerRef.current);
                }

                if (drawingPoints.length > 2) {
                    L.polyline([drawingPoints[drawingPoints.length - 1], drawingPoints[0]], { color: '#3b2b1d', dashArray: '5, 10', opacity: 0.5, weight: 3 }).addTo(drawingLayerRef.current);
                }
            }
        }
    }, [drawingPoints, mode]);

    // --- Actions ---
    const handleDeleteZone = async (id) => {
        if (!window.confirm('¿Seguro que deseas eliminar los documentos de esta geolocalización?')) return;
        const { error } = await supabase.rpc('delete_map_zone', { p_id: id });
        if (error) alert('Error: ' + error.message);
        else fetchZones();
    };

    const prepareEdit = (zone) => {
        setTempZoneData({
            name: zone.name,
            description: zone.description || '',
            color: '#3b2b1d' // Forzar siempre tinta carbón oscura estilo mapa
        });
        setEditingZoneId(zone.id);
        setShowModal(true);
    };

    const handleFinishDraw = () => {
        if (drawingPoints.length < 3) return alert("Debes marcar al menos 3 puntos en el compás cartográfico.");
        setEditingZoneId(null); 
        setTempZoneData({ name: '', description: '', color: '#3b2b1d' });
        setShowModal(true);
    };

    const handleSaveZone = async () => {
        if (!tempZoneData.name) return alert("Se requiere un título para la zona.");

        let error;
        if (editingZoneId) {
            const res = await supabase.rpc('update_map_zone', {
                p_id: editingZoneId,
                p_name: tempZoneData.name,
                p_description: tempZoneData.description,
                p_color: tempZoneData.color
            });
            error = res.error;
        } else {
            const res = await supabase.rpc('create_map_zone', {
                p_name: tempZoneData.name,
                p_description: tempZoneData.description,
                p_coordinates: drawingPoints,
                p_color: tempZoneData.color
            });
            error = res.error;
        }

        if (error) {
            alert('Error cartográfico: ' + error.message);
        } else {
            fetchZones();
            setMode('view');
            setDrawingPoints([]);
            setShowModal(false);
            setEditingZoneId(null);
            setTempZoneData({ name: '', description: '', color: '#3b2b1d' });
        }
    };

    return (
        <div style={{ position: 'relative', height: 'calc(100vh - 140px)', width: '100%', overflow: 'hidden', background: '#d0b58f', borderRadius: '4px', border: '2px solid #3b2b1d' }}>

            <div ref={mapContainerRef} style={{ width: '100%', height: '100%', outline: 'none' }} />

            <div className="rdr-map-toolbar">
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', borderBottom: '1px solid rgba(212, 175, 55, 0.4)', paddingBottom: '10px' }}>
                    <div style={{ width: '12px', height: '12px', background: '#d4af37', borderRadius: '50%', boxShadow: '0 0 10px #d4af37' }}></div>
                    <h3 style={{ margin: 0, color: '#d4af37', fontFamily: 'Cinzel', fontSize: '1.2rem', textShadow: '1px 1px 3px rgba(0,0,0,0.8)' }}>
                        CARTOGRAFÍA
                    </h3>
                </div>

                {authorized ? (
                    mode === 'view' ? (
                        <button
                            onClick={() => setMode('draw')}
                            className="rdr-btn-brown"
                            style={{fontSize: '0.85rem'}}
                        >
                            + DELIMITAR ZONA
                        </button>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                            <div style={{ fontSize: '0.85rem', color: '#c0a080', fontFamily: 'Playfair Display', fontStyle: 'italic', borderBottom: '1px solid #4a3321', paddingBottom: '10px' }}>
                                Clava chinchetas en el mapa.<br/>Click Izquierdo: Clavar<br/>Click Derecho: Deshacer
                            </div>
                            <button
                                onClick={handleFinishDraw}
                                className="rdr-btn-brown"
                                disabled={drawingPoints.length < 3}
                            >
                                Registrar Papeles
                            </button>
                            <button
                                onClick={() => { setMode('view'); setDrawingPoints([]); }}
                                className="rdr-btn-brown"
                                style={{background: 'transparent', borderColor: '#8b0000', color: '#8b0000'}}
                            >
                                Cancelar
                            </button>
                        </div>
                    )
                ) : (
                    <div style={{ fontSize: '0.9rem', color: '#8b5a2b', fontFamily: 'Cinzel', fontStyle: 'italic' }}>
                        Acceso Visual (Restringido)
                    </div>
                )}
            </div>

            {/* Editing Modal */}
            {showModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{ maxWidth: '400px' }}>
                        <h2 style={{ textAlign: 'center', marginBottom: '1.5rem' }}>
                            {editingZoneId ? 'REVISAR ARCHIVOS DE ZONA' : 'CLASIFICAR NUEVA ZONA'}
                        </h2>

                        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', textAlign: 'left' }}>
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', marginBottom: '0.5rem', display: 'block', textTransform: 'uppercase'}}>Designación de Zona</label>
                                <input
                                    className="rdr-input"
                                    value={tempZoneData.name}
                                    onChange={e => setTempZoneData({ ...tempZoneData, name: e.target.value })}
                                />
                            </div>

                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', marginBottom: '0.5rem', display: 'block', textTransform: 'uppercase'}}>Notas (Opcional)</label>
                                <textarea
                                    className="rdr-input"
                                    rows="4"
                                    value={tempZoneData.description}
                                    onChange={e => setTempZoneData({ ...tempZoneData, description: e.target.value })}
                                />
                            </div>



                            <div style={{ display: 'flex', gap: '10px', marginTop: '1rem' }}>
                                <button
                                    onClick={() => setShowModal(false)}
                                    className="rdr-btn-brown"
                                    style={{ flex: 1, background: 'transparent', borderColor: '#c0a080', color: '#c0a080' }}
                                >
                                    Cancelar
                                </button>
                                <button
                                    onClick={handleSaveZone}
                                    className="rdr-btn-brown"
                                    style={{ flex: 1 }}
                                >
                                    Fijar Información
                                </button>
                            </div>
                        </div>

                    </div>
                </div>
            )}
        </div>
    );
}
