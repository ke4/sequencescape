module IlluminaB::PlatePurposes
  PLATE_PURPOSE_FLOWS = [
    [
      'ILB_STD_INPUT',
      'ILB_STD_COVARIS',
      'ILB_STD_SH',
      'ILB_STD_PREPCR',
      'ILB_STD_PCR',
      'ILB_STD_PCRR',
      'ILB_STD_PCRXP'
    ]
  ]

  TUBE_PURPOSE_FLOWS = [
    [
      'ILB_STD_STOCK',
      'ILB_STD_MX'
    ]
  ]

  BRANCHES = [
    [ 'ILB_STD_INPUT', 'ILB_STD_COVARIS', 'ILB_STD_SH', 'ILB_STD_PREPCR', 'ILB_STD_PCR', 'ILB_STD_PCRXP', 'ILB_STD_STOCK', 'ILB_STD_MX' ],
    [ 'ILB_STD_PREPCR', 'ILB_STD_PCRR', 'ILB_STD_PCRXP' ]
  ]

  STOCK_PLATE_PURPOSE = 'ILB_STD_INPUT'

  # Don't have ILllumina B QC plates at the momnet...
  PLATE_PURPOSE_LEADING_TO_QC_PLATES = [
  ]

  PLATE_PURPOSES_TO_REQUEST_CLASS_NAMES = [
    [ 'ILB_STD_COVARIS', 'ILB_STD_SH',    'IlluminaB::Requests::CovarisToSheared' ],
    [ 'ILB_STD_PREPCR',  'ILB_STD_PCR',   'IlluminaB::Requests::PrePcrToPcr'      ],
    [ 'ILB_STD_PREPCR',  'ILB_STD_PCRR',  'IlluminaB::Requests::PrePcrToPcr'      ],
    [ 'ILB_STD_PCR',     'ILB_STD_PCRXP', 'IlluminaB::Requests::PcrToPcrXp'       ],
    [ 'ILB_STD_PCRR',    'ILB_STD_PCRXP', 'IlluminaB::Requests::PcrToPcrXp'       ],
    [ 'ILB_STD_PCRXP',   'ILB_STD_STOCK', 'IlluminaB::Requests::PcrXpToStock'     ]
  ]

  PLATE_PURPOSE_TYPE = {
    'ILB_STD_INPUT'   => IlluminaB::StockPlatePurpose,
    'ILB_STD_COVARIS' => IlluminaB::CovarisPlatePurpose,
    'ILB_STD_SH'      => PlatePurpose,
    'ILB_STD_PREPCR'  => PlatePurpose,
    'ILB_STD_PCR'     => IlluminaB::PcrPlatePurpose,
    'ILB_STD_PCRXP'   => IlluminaB::FinalPlatePurpose,
    'ILB_STD_PCRR'    => PlatePurpose,
    'ILB_STD_STOCK'   => IlluminaB::StockTubePurpose,
    'ILB_STD_MX'      => IlluminaB::MxTubePurpose
  }

  # We only have one flow at the moment
  class << self
    def create_plate_purposes
      IlluminaB::PlatePurposes::PLATE_PURPOSE_FLOWS.each do |flow|
        stock_plate = create_plate_purpose(flow.shift, :can_be_considered_a_stock_plate => true, :default_state => 'passed', :cherrypickable_target => true)
        request_type_for(stock_plate).acceptable_plate_purposes << stock_plate

        flow.each(&method(:create_plate_purpose))
      end
      IlluminaB::PlatePurposes::TUBE_PURPOSE_FLOWS.each do |flow|
        stock_tube = create_tube_purpose(flow.shift, :target_type => 'StockMultiplexedLibraryTube')
        flow.each(&method(:create_tube_purpose))
      end

      IlluminaB::PlatePurposes::BRANCHES.each do |branch|
        branch.inject(Purpose.find_by_name(branch.shift)) do |parent, child|
          Purpose.find_by_name(child).tap do |child_purpose|
            parent.child_relationships.create!(:child => child_purpose, :transfer_request_type => request_type_between(parent, child_purpose))
          end
        end
      end
    end

    def request_type_for(stock_plate)
      # Only have one at the moment
      RequestType.find_by_key('illumina_b_std')
    end
    private :request_type_for

    def purpose_for(name)
      IlluminaB::PlatePurposes::PLATE_PURPOSE_TYPE[name]
    end
    private :purpose_for

    def request_type_between(parent, child)
      _, _, request_class = IlluminaB::PlatePurposes::PLATE_PURPOSES_TO_REQUEST_CLASS_NAMES.detect { |a,b,_| (parent.name == a) && (child.name == b) }
      return RequestType.transfer if request_class.nil?
      request_type_name = "Illumina-B #{parent.name}-#{child.name}"
      RequestType.create!(:name => request_type_name, :key => request_type_name.gsub(/\W+/, '_'), :request_class_name => request_class, :asset_type => 'Well', :order => 1)
    end
    private :request_type_between

    def create_plate_purpose(plate_purpose_name, options = {})
      purpose_for(plate_purpose_name).create!(options.reverse_merge(
        :name                  => plate_purpose_name,
        :cherrypickable_target => false,
        :cherrypick_direction  => 'row'
      )).tap do |plate_purpose|
        plate_purpose.barcode_printer_type = BarcodePrinterType.find_by_type('BarcodePrinterType96Plate')||plate_purpose.barcode_printer_type
      end
    end
    private :create_plate_purpose

    def create_tube_purpose(tube_purpose_name, options = {})
      purpose_for(tube_purpose_name).create!(options.reverse_merge(
        :name                 => tube_purpose_name,
        :target_type          => 'MultiplexedLibraryTube',
        :barcode_printer_type => BarcodePrinterType.find_by_type('BarcodePrinterType1DTube')
      ))
    end
    private :create_tube_purpose
  end
end
