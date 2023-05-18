describe('Cloud Resume Spec', () => {
  it('passes', () => {
    cy.visit('https://d1g0abils84b1g.cloudfront.net/')
    
    //Commenting out until CF distribution is set up with domain name
    //cy.visit('https://www.ilgallion.com/index.html')
    //cy.location().should((page) => {
      //expect(page.hostname).to.equal('www.ilgallion.com');
      //expect(page.protocol).to.equal('https:');
    //});
    
    cy.title().should('contain', 'Resume');
    cy.contains('Isaac Gallion Resume');
      });
  })