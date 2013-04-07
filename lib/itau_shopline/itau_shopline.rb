# -*- encoding: UTF-8 -*-

require "net/https"
require "uri"
require "rexml/document"
require "open-uri"

class ItauShopline
	include ActionView::Helpers::NumberHelper

	STATUS_TRANSLATE = {
		:pending => 'Pendente',
		:paid => 'Pago'
	}
	
	PAYMENT_TRANSLATE = {
		:undefined => 'Não definido',
		:online_transfer => 'Transferência',
		:invoice => 'Boleto',
		:credit_card => 'Cartão de crédito'
	}

	STATUS = {
		:undefined => {
			'01' => :pending,
			'02' => :pending,
			'03' => :pending
		},
		:online_transfer => {
			'00' => :paid,
			'01' => :pending,
			'02' => :pending,
			'03' => :pending      
		},
		:invoice => {
			'00' => :paid,
			'01' => :pending,
			'02' => :pending,
			'03' => :pending,
			'04' => :pending,
			'05' => :paid,
			'06' => :pending   
		},
		:credit_card => {
			'00' => :paid,
			'01' => :pending,
			'02' => :pending,
			'03' => :pending      
		}
	}
	
	PAYMENT_METHODS = {
		'00' => :undefined,
		'01' => :online_transfer,
		'02' => :invoice,    
		'03' => :credit_card
	}
	
	def gera_dados(params)
		default = {codigo_da_empresa: nil,
		pedido: nil,
		valor: nil,
		observacao: nil,
		chave: nil,
		nome_do_sacado: nil,
		codigo_da_inscricao: nil,
		numero_da_inscricao: nil,
		endereco_do_sacado: nil,
		bairro_do_sacado: nil,
		cep_do_sacado: nil,
		cidade_do_sacado: nil,
		estado_do_sacado: nil,
		data_de_vencimento: nil,
		url_de_retorno: nil,
		obs_adicional1: nil,
		obs_adicional2: nil,
		obs_adicional3: nil}

		params = default.merge!(params) { |key, v1, v2| v2 }

		params[:codigo_da_inscricao] = (params[:codigo_da_inscricao] == :cpf) ? "01" : "02"
		params[:codigo_da_empresa] = config["codigo_empresa"]
		params[:chave] = config["chave"]
		params[:valor] = number_to_currency(params[:valor], :unit => "", :separator => ",", :delimiter => "")
		params[:data_de_vencimento] = params[:data_de_vencimento].strftime('%d%m%Y')

		cripto = ItauCripto.new
		cripto.gera_dados(params.values.collect(&:to_s))
	end

	def dcript_transaction_notify(dados)
		cripto = ItauCripto.new
		cripto.decripto(dados, config['chave'])    
	end
	
	def get_invoice_details(invoice_id)
		cripto = ItauCripto.new
		token = cripto.gera_consulta(config['codigo_empresa'], invoice_id.to_s, '1',config['chave'])
		xml = open("https://shopline.itau.com.br/shopline/consulta.aspx?DC=#{token}").read

		treat_itau_data xml    
	end
	
	private
		def treat_itau_data(dados)
			treated_data = {}

			response = REXML::Document.new(dados)
			params  = response.elements['consulta'].elements['PARAMETER']
			params.elements.each do |param|
				treated_data[param.attributes['ID']] = param.attributes['VALUE']
			end
			
			new_result = {}
			treated_data.each do |field, value|
				value = PAYMENT_METHODS[value] if field == 'tipPag'
				value = STATUS[PAYMENT_METHODS[treated_data['tipPag']]][value] if field == 'sitPag'        

				new_result[field] = value
			end
			
			new_result
		end
	
		def config
			{'codigo_empresa' => ENV["ITAU_ENTERPRISE"], 'chave' => ENV["ITAU_KEY"]}
		end
end