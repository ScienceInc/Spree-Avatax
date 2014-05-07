module Spree
  Order.class_eval do
      Spree::Order.state_machine.after_transition :to => :complete, :do => :commit_avatax_invoice

      #TODO-  Avatax Refunds!

      def commit_avatax_invoice
            begin
              Avalara.password = AvataxConfig.password
              Avalara.username = AvataxConfig.username
              Avalara.endpoint = AvataxConfig.endpoint
              
              #Only send the line items that return true for avataxable
              matched_line_items = self.line_items.select do |line_item|
                line_item.avataxable
              end

              invoice_lines =[]
              line_count = 0

              discount = 0
              credits = self.adjustments.select {|a| a.amount<0}
              discount = -(credits.sum &:amount)
              matched_line_items.each do |matched_line_item|
                line_count = line_count + 1
                matched_line_amount = matched_line_item.price * matched_line_item.quantity
                invoice_line = Avalara::Request::Line.new(
                  :line_no => line_count.to_s,
                  :destination_code => '1',
                  :origin_code => '1',
                  :qty => matched_line_item.quantity.to_s,
                  :amount => matched_line_amount.to_s,
                  :discounted => true
                )
                invoice_lines << invoice_line                
              end

              invoice_addresses = []
              invoice_address = Avalara::Request::Address.new(
                :address_code => '1',
                :line_1 => self.ship_address.address1.to_s,
                :line_2 => self.ship_address.address2.to_s,
                :city => self.ship_address.city.to_s,
                :postal_code => self.ship_address.zipcode.to_s
              )
              invoice_addresses << invoice_address

              invoice = Avalara::Request::Invoice.new(
                :customer_code => self.email,
                :doc_date => self.completed_at.to_date,
                :doc_type => 'SalesInvoice',
                :company_code => AvataxConfig.company_code,
                :doc_code => self.number,
                :commit => 'true',
                :discount => discount
              )

              invoice.addresses = invoice_addresses
              invoice.lines = invoice_lines

              #Log request
              logger.debug 'Avatax Request - '
              logger.debug invoice.to_s

              invoice_tax = Avalara.get_tax(invoice)

              #Log Response
              logger.debug 'Avatax Response - '
              logger.debug invoice_tax.to_s
            rescue => error
              Honeybadger.notify(error)
              logger.debug 'Avatax Commit Failed!'
              logger.debug error.to_s
            end
      end
  end
end