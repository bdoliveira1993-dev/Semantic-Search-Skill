-- =============================================================================
-- Example data for testing the semantic-search skill
-- =============================================================================
-- 30 synthetic items across multiple categories to demonstrate both textual
-- and semantic search. Run this AFTER setup.sql.
-- After loading, run: SELECT generate_embeddings_batch(30);
-- =============================================================================

insert into public.items (code, name, category, subcategory, supplier, unit, unit_price, specs) values

-- ELECTRICAL
('EL-001', 'Copper cable 2.5mm² 750V black',            'ELECTRICAL', 'CONDUCTORS',   'GenericCo',  'M',  3.20, 'PVC insulation, flexible, class 5'),
('EL-002', 'Copper cable 4mm² 750V blue',               'ELECTRICAL', 'CONDUCTORS',   'GenericCo',  'M',  4.80, 'PVC insulation, flexible, class 5'),
('EL-003', 'Copper cable 10mm² 0.6/1kV green-yellow',   'ELECTRICAL', 'CONDUCTORS',   'WireMaster', 'M', 11.50, 'XLPE insulation, ground wire'),
('EL-004', 'Circuit breaker 1P 20A C curve',            'ELECTRICAL', 'PROTECTION',   'BreakerPro', 'EA', 18.00, 'DIN rail, 6kA breaking capacity'),
('EL-005', 'Circuit breaker 3P 63A C curve',            'ELECTRICAL', 'PROTECTION',   'BreakerPro', 'EA', 145.00, 'DIN rail, 10kA breaking capacity'),
('EL-006', 'Transformer 500 kVA 13.8kV/380V dry type',  'ELECTRICAL', 'TRANSFORMERS', 'TransformCo','EA', 48000.00, 'Cast resin, IP21, indoor'),
('EL-007', 'Transformer 225 kVA 13.8kV/380V oil',       'ELECTRICAL', 'TRANSFORMERS', 'OilTrans',   'EA', 28500.00, 'Mineral oil, pole mount'),
('EL-008', 'LED luminaire 40W recessed 60x60',          'ELECTRICAL', 'LIGHTING',     'LumenCo',    'EA', 95.00, '4000K, 4000lm, IP40'),
('EL-009', 'LED high bay 150W industrial',              'ELECTRICAL', 'LIGHTING',     'LumenCo',    'EA', 320.00, '5000K, 19500lm, IP65'),
('EL-010', 'Power analyzer 3-phase 600V',               'ELECTRICAL', 'INSTRUMENTS',  'MeterTech',  'EA', 2450.00, 'True RMS, Modbus RTU, class 0.5'),

-- FIRE_PROTECTION
('FP-001', 'Sprinkler pendent ESFR K25.2 brass',        'FIRE_PROTECTION', 'SPRINKLERS', 'SprinkCo',  'EA', 85.00, 'Response time index 50, UL listed'),
('FP-002', 'Sprinkler upright standard K5.6 chrome',    'FIRE_PROTECTION', 'SPRINKLERS', 'SprinkCo',  'EA', 28.00, 'Response time index 50, 68°C bulb'),
('FP-003', 'Steel pipe 4" schedule 40 ASTM A53',        'FIRE_PROTECTION', 'PIPING',     'PipeMaster','M',  92.00, 'Black, grooved ends, FM approved'),
('FP-004', 'Victaulic coupling 4" rigid',               'FIRE_PROTECTION', 'FITTINGS',   'VictCo',    'EA', 45.00, 'Ductile iron, UL/FM'),
('FP-005', 'Fire pump 500 GPM 100 PSI diesel',          'FIRE_PROTECTION', 'PUMPS',      'PumpForce', 'EA', 78500.00, 'NFPA 20 compliant, UL listed'),
('FP-006', 'VESDA aspirating smoke detector',           'FIRE_PROTECTION', 'DETECTION',  'VESDACo',   'EA', 4200.00, 'Laser detection, 4 alarm thresholds'),
('FP-007', 'Alarm valve 4" wet pipe',                   'FIRE_PROTECTION', 'VALVES',     'ValveKing', 'EA', 1850.00, 'UL/FM, with retard chamber'),

-- HVAC
('HV-001', 'Galvanized steel duct 300x200 mm',          'HVAC', 'DUCTWORK',  'DuctWorks',  'M',   68.00, '1.0mm thickness, TDC flange'),
('HV-002', 'Flexible duct insulated 8" 10m',            'HVAC', 'DUCTWORK',  'FlexAir',    'ROLL', 240.00, 'Fiberglass insulation R4.2'),
('HV-003', 'Axial fan 500mm 3000 m³/h',                 'HVAC', 'FANS',      'FanMaster',  'EA',  1850.00, 'Three-phase, IP54'),
('HV-004', 'Chilled water pump 10 HP',                  'HVAC', 'PUMPS',     'PumpForce',  'EA',  6200.00, 'End suction, cast iron'),
('HV-005', 'VRF outdoor unit 20 HP',                    'HVAC', 'UNITS',     'CoolTech',   'EA', 32000.00, 'Heat pump, R410A, 380V'),

-- PLUMBING
('PL-001', 'PPR pipe 25mm PN20 6m',                     'PLUMBING', 'PIPING',   'PlastiPipe', 'BAR',  42.00, 'Hot water rated, fusion weld'),
('PL-002', 'Stainless steel tube 316L 2" sanitary',     'PLUMBING', 'PIPING',   'SteelTube',  'M',   185.00, 'Polished, orbital weld ready'),
('PL-003', 'Ball valve 2" full port brass',             'PLUMBING', 'VALVES',   'ValveKing',  'EA',   125.00, 'Threaded, 600 PSI WOG'),
('PL-004', 'Booster pump 1.5 HP stainless',             'PLUMBING', 'PUMPS',    'PumpForce',  'EA',  3200.00, 'Multi-stage, for potable water'),

-- INSTRUMENTATION
('IN-001', 'Pressure transmitter 0-10 bar 4-20mA',      'INSTRUMENTATION', 'PRESSURE', 'SensorPro','EA', 980.00, 'HART protocol, 316SS wetted'),
('IN-002', 'Temperature transmitter Pt100 head mount',  'INSTRUMENTATION', 'TEMPERATURE', 'SensorPro','EA', 320.00, 'HART, 4-20mA output'),
('IN-003', 'Magnetic flow meter 4" 316L',               'INSTRUMENTATION', 'FLOW',     'FlowTech', 'EA', 4500.00, 'PTFE liner, Modbus TCP'),
('IN-004', 'Level radar transmitter 30m range',         'INSTRUMENTATION', 'LEVEL',    'SensorPro','EA', 3800.00, '80 GHz, HART, tank apps')

;

-- =============================================================================
-- After running this file:
--   SELECT generate_embeddings_batch(30);
-- to populate the embedding vectors for all 30 items.
-- =============================================================================
