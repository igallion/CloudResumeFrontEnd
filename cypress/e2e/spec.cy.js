describe('Cloud Resume Spec', () => {
  it('passes', () => {
    cy.visit('resume.ilgallion.com')
    
    cy.visit('https://resume.ilgallion.com')
    cy.location().should((page) => {
      expect(page.hostname).to.equal('resume.ilgallion.com');
      expect(page.protocol).to.equal('https:');
    });
    
    cy.title().should('contain', 'Resume');
    cy.contains('Isaac Gallion Resume');
      });
  })